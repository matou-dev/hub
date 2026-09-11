---
type: spec
status: active
maturity: standard
scope: spi
roadmap: -
---

# Virtual Hitboxes — pure geometry ray-testing and authoritative validation

Date: 2026-09-11
Status: active

## Problem

In Minecraft vanilla, combat hit detection is coupled to a single coarse bounding box
per entity, with asymmetric client/server resolution (the client raycasts against interpolated
positions and sends only the target entity ID; the server merely validates that
`distance(player, entity) < maxReach`). This causes two critical failure modes:
1. **No Part/Bone Granularity**: Cannot target specific limbs, head weakspots, or armored zones.
2. **BUG-042 (Large Entity Melee Failure)**: For large entities whose origin is far from their
   outer extremities, the vanilla origin-distance check rejects legitimate hits on the limbs or wings.

## Decision

Virtual Hitboxes decouple hit resolution into a pure geometric ray-box intersection
pipeline located in `matou-spi` (`fr.iamacat.spi.hit`), completely free of Minecraft
and OpenGL imports.

### 1. Data Structures (`fr.iamacat.spi.hit`)

- **`Vec3d`**: Immutable double-precision 3-vector (`x, y, z`) providing vector operations:
  `add`, `sub`, `scale`, `dot`, `lengthSquared`, `length`, `normalize`.
- **`AABBd`**: Immutable double-precision axis-aligned bounding box defined by
  `[minX, minY, minZ]` to `[maxX, maxY, maxZ]`.
  - `intersect(ox, oy, oz, dx, dy, dz, maxDist)`: Evaluates ray-box intersection via the
    Kay-Kajiya slab method. Returns entry scalar $t \ge 0$ (or $0.0$ if the ray origin is
    inside the box) within $[0, \text{maxDist}]$, or `Double.NaN` if no intersection occurs.
  - Rejects degenerate coordinates (`min > max`) or NaN components with `E_HIT_BOX:degenerate`
    and `E_HIT_BOX:nan`.
- **`BoneBox`**: Associates a logical bone identifier (`boneName`) with an `AABBd`.
- **`RayHit`**: Immutable result of a successful ray intersection:
  - `boneName`: Name of the struck bone.
  - `hitVec`: Exact world-space point of intersection (`Vec3d`).
  - `distance`: True world distance from ray origin to `hitVec`.
- **`Hittable`**: Pure SPI interface implemented by targets:
  - `List<BoneBox> hitBoxes()`: Returns the collection of active bone bounding boxes.
  - `Map<String, Float> hitWeakspots()`: Returns damage multipliers per bone (e.g. `"head" -> 2.0F`).
  - `float weakspotMultiplier(String boneName)`: Resolves damage multiplier (default `1.0F`).

### 2. Algorithmic Ray Testing (`HitTester`)

`HitTester.test(List<BoneBox> boxes, Vec3d origin, Vec3d dir, double maxDist)`:
1. Validates inputs: rejects null/NaN origins, zero-length or NaN direction vectors, and negative reach.
2. Normalizes `dir` to guarantee that the returned parameter $t$ equals Euclidean world distance.
3. Tests ray against each `BoneBox` in the collection.
4. Selects the minimum $t \ge 0$ across all candidate boxes.
5. Computes exact impact position $\mathbf{p} = \text{origin} + t \cdot \text{dir}$.
6. Returns `RayHit(bestBone, p, minT)` or `null` if no boxes intersect within `maxDist`.

### 3. Client/Server Authoritative Validation Lifecycle

1. **Client-Side (Prediction & Feedback)**:
   - Player triggers attack.
   - Client executes `HitTester.test(target, eyePos, lookVec, reach)`.
   - On hit: client displays instantaneous visual/crosshair feedback and sends an attack packet
     containing `(entityId, boneName, hitVec, distance)`.
2. **Server-Side (Authoritative Validation)**:
   - Server receives packet.
   - Server verifies player reach and line of sight.
   - Server evaluates the **identical** pure function:
     `HitTester.test(target, serverEyePos, serverLookVec, serverMaxReach)`.
   - If the server calculation confirms that `boneName` was hit within spatial tolerance,
     the hit is approved and `weakspotMultiplier(boneName)` is factored into damage calculation.
   - If the ray misses or targets an unhit bone, the hit is rejected without applying damage.

### 4. Error Catalog (`E_HIT_*`)

- `E_HIT_ORIGIN:nan`: Ray origin coordinates contain NaN.
- `E_HIT_ORIGIN:null`: Ray origin vector is null.
- `E_HIT_DIR:zero`: Ray direction vector has zero length.
- `E_HIT_DIR:nan`: Ray direction vector contains NaN.
- `E_HIT_DIR:null`: Ray direction vector is null.
- `E_HIT_DIST:negative`: Maximum reach distance is negative.
- `E_HIT_DIST:nan`: Maximum reach distance is NaN.
- `E_HIT_BOX:degenerate`: AABB min bounds exceed max bounds.
- `E_HIT_BOX:nan`: AABB bounds contain NaN.
- `E_HIT_TARGET:null`: Target hittable or bone box list is null.

## Gates

- `spi/tools/check.sh` green:
  - `zero-mc-import` passes.
  - `javac --release 8` compiles `fr.iamacat.spi.hit.*` without errors.
  - Test suite `HitCheck` passes with comprehensive coverage:
    - Ray-AABB intersection goldens (center hit, corner hit, miss, ray origin inside box).
    - Ray parallel to slab planes (inside vs outside slab).
    - Multi-bone ordering: closer bone occlusion over farther bones.
    - Input rejection for all `E_HIT_*` error codes.
    - Weakspot damage calculation.

## Addendum — server weakspot hook, bridge-1122 e0 (2026-09-11)

Lead-bridge E0 (stages 1-2 green, live proof TODO — user-scoped
`Server weakspot hook`: LivingHurt refinement only, no packet, no
client prediction): `MatouBridgeMod.onHurt` resolves every
server-side dim-0 hurt on the registered beast through the pure
`HitTester` and scales the vanilla amount by the bone weakspot
multiplier (`head` 2x from the beast-local `BeastModel.WEAKSPOTS`
table).

- Attacker eye/look read version-native through the declaring
  `Entity` type (owner discipline, hub `decisions/LOOT.md`):
  `getLookVec` (`func_70040_Z ()->Vec3d`), `getEyeHeight`
  (`func_70047_e ()F`), `DamageSource.getTrueSource`
  (`func_76346_g ()->Entity`, anchored against the same-descriptor
  `func_76364_f` sibling) and the look components `Vec3d/x/y/z`
  (`field_72450_a/b/c`) — all javap-measured on the pinned 2860
  bytes (obf `vg/aJ`, `vg/by`, `ur/j`, `bhe/b/c/d`), narrow-map rows
  43-48, Forge `LivingHurtEvent` ctor + `getSource`/`getAmount`/
  `setAmount` presence-pinned against the 2860 universal.
- `COMBAT_REACH = 4.0`: eye-to-hitVec cutoff. Vanilla survival
  validates ~3.0 eye-to-ORIGIN, but bone boxes extend a block past
  the origin (the head rides 0.97..1.53 above the feet), so a
  legitimate headshot's eye-to-surface distance exceeds the origin
  budget — 4.0 is vanilla 3.0 plus one block of bone extent, a
  constant with its derivation written down (attribute-driven reach
  is a named re-opener, never a quiet fallback).
- Fallback discipline: environmental hurts (null attacker), hurts the
  coarse vanilla box caught but no bone box covers (glancing), and
  non-beast targets keep vanilla silently — the hook refines
  delivered hurts, it never vetoes. Corrupt attacker state (NaN eye
  or a zero look) refuses loudly out of the SPI constructors
  (`E_HIT_VEC:nan` / `E_HIT_DIR:zero`), never a defaulted
  multiplier. The vanilla pre-rejection (BUG-042 — an origin veto
  that never fires this event) stays vanilla: named re-opener,
  never smuggled in.
- Live leg (autoplay, `COMBAT=1` on a `SPAWN=1` direct-client run):
  teleports the joined player 2.2 blocks east of the first living
  beast on its ground plane (flat proof world, well inside the
  vanilla reach so the genuine path delivers, far enough that the
  descending eye-1.62 -> head-1.25 ray clears the body-box top and
  lands the head first), aims at the SPI-parsed head center (aim
  self-check re-derives the look with the vanilla formula and
  demands dot > 0.999), strikes via the genuine
  `attackTargetEntityWithCurrentItem`, and polls the wound: exactly
  2.0 (bare-hand 1.0 x head 2x — a body shot reads 1.0, a crit 3.0,
  a lost hurt 0.0, all three fail the exact assert loudly). Bridge
  logs `[MatouBridge] combat resolved <bone=...>`; companion logs
  `[MatouAutoplay] combat struck/resolved <...>`; the run shuts
  down FAILED on any combat leg failure like every other proof leg.
- `PORT_QUEUE` row `Combat weakspot hook` (`BRIDGE_PARITY.md`):
  `TODO | e0 | TODO | TODO`.

## Addendum — live proof, bridge-1122 (2026-09-11)

`bridge-1122` `9ae00d4` (E0) + `840507c` (live fix) proves the hook
live on Forge 2860 (launcher-free headless direct-client run,
`SPAWN=1 COMBAT=1`, Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502):

- Server re-proof green with the 48-line map (bind clean, ticks
  clean, world == pure union 1922 cells — hook present but dormant,
  zero `E_HIT`, zero combat lines on the playerless dedicated
  server).
- Client: census 1→4 at worldTicks 2..5, `spawn hp <20.0>`, then
  `[MatouBridge] combat resolved <bone=head mult=2.0 dmg=1.0->2.0>`
  at worldTick 500 (the SPI ray-test off the live attacker eye/look
  landed the head box first, vanilla 1.0 scaled to 2.0),
  `[MatouAutoplay] combat struck <head hp=20.0>` the same tick,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, i.e. bare-hand 1.0 x head
  2x, no crit, no fallback), spawn kill at 1000 → gem carrier at
  1001 (elapsed 1, chain intact on the wounded beast).
- `verify-client-save.sh` world == pure union (1274 cells, stone) ;
  zero `E_*` / linkage lines in `game.log`.
- Trouvaille (owner-discipline class, one server crash): the first
  play run died with `NoSuchFieldError: posX` in
  `MatouEntity.hitBoxes` — bare `posX` reads owner `MatouEntity`,
  whose reobf walk dies at the vanilla `EntityPig` link (vanilla
  classes are absent from the reobf input, so a subclass-owner ref
  passes through silently and dies linking live — the same trap
  `E_MAP_COVER` was built for on the renderer path, and the scan
  cannot catch it because it walks the stub-inclusive build jar
  where the chain exists). Fix (`840507c`): read through a
  declaring-`Entity`-typed self, like every other hook. The crash
  itself proved the rest of the path first try (teleport, aim,
  genuine strike, event delivery, `HitTester` entry).
- `PORT_QUEUE` row `Combat weakspot hook` flips to
  `TODO | live | TODO | TODO`.

## Addendum — port live, bridge-1710 (2026-09-11)

`bridge-1710` `722097b` ports the hook version-native, proven live
the same day (150 s Forge 1614 server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb/llvmpipe, exit 0, host
OpenJDK 1.8.0_502):

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,165 — hook dormant, zero `E_HIT`).
- Client: `[MatouBridge] combat resolved <bone=head mult=2.0
  dmg=1.0->2.0>` at worldTick 500, autoplay exact-2.0 wound
  (20.0 → 18.0, elapsed 1), spawn kill at 1000 → gem carrier at
  1001, clean shutdown after 4600 server ticks ;
  `verify-client-save.sh` world == pure union (1274 cells, stone) ;
  zero `E_*` / linkage lines.
- 1614-native shapes (srg-mcp.srg-measured, full-map era — no narrow
  map): public-field events (`LivingEvent.entityLiving`,
  `LivingHurtEvent.source`, `LivingHurtEvent.ammount` — the Forge
  typo mirrored verbatim), `DamageSource.getEntity` (the 1122
  `getTrueSource` does not exist here — same searge
  `func_76346_g`), `Vec3.xCoord/yCoord/zCoord` (no `Vec3d` here),
  `worldObj` / `dimensionId`, 6-arg `LivingDropsEvent` untouched.
  The 1122 `hitBoxes` owner fix rides along (same bare-`posX`
  shape). Bare-hand base is 1.0 here too, no crit on the standing
  teleport — the exact-2.0 assert held first try.
- Trouvaille (hub tooling, same run): the shared crash-fast watcher
  (landed after the 1710 visual proof) killed the healthy game on
  1.7.10's SplashProgress boot banner (`---- Minecraft Crash Report
  ---- ... THIS IS NOT A ERROR`, exit 143, no save). Fixed in hub
  `1f305b3`: the watcher trips on `#@!@# Game crashed!` (every real
  crash prints it, server tick loops included), never on the bare
  header.
- `PORT_QUEUE` row `Combat weakspot hook` flips to
  `live | live | TODO | TODO` (0 `e0` remaining).

## Addendum — port E0, bridge-1165 (2026-09-11)

`bridge-1165` `531799c` ports the hook version-native, E0-green
(stages 1-2, live proof TODO — same bar as the 1122 lead E0): the
same 11-file shape (hook + autoplay `COMBAT=` leg + stubs + narrow
map + pins + verdict).

- 36.2.42-native shapes (snapshot 20210309 + joined.tsrg + javap
  measured, never ported blind): the hurt entity behind
  `LivingEvent.getEntityLiving()` as `LivingEntity`, the source behind
  `LivingHurtEvent.getSource()`, the true attacker behind
  `DamageSource.getTrueSource` (`func_76346_g ()->Entity`, obf
  `apk/k` — the same-descriptor `func_76364_f` sibling is not the
  true source, hence the SRG anchor); eye/look through the declaring
  `Entity` (`getLookVec` `func_70040_Z ()->Vector3d`, obf `aqa/bh`;
  `getEyeHeight` `func_70047_e ()F`, obf `aqa/ce`); the origin
  through the already-pinned `getPosX/Y/Z` (1.16.5 keeps no `posX`
  fields — the 1.12 field shape does not port, and the declaring-`Entity`
  read rides the 1122 owner-discipline fix by construction); the look
  components on the declaring `Vector3d` (`field_72450_a/b/c = x/y/z`,
  obf `dcn/b/c/d` — the 1.12 `Vec3d` owner does not port); the dim
  gate stays the `OVERWORLD` key; `LivingHurtEvent(LivingEntity,
  DamageSource, float)` + `getSource`/`getAmount`/`setAmount`
  presence-pinned against the 36.2.42 universal (Forge-added, never
  obfuscated).
- Narrow map 48 -> 54 rows (combat tranche, hub `tools/live-derive.sh`
  era-1.16 assert bumped in the same tranche): the 6 new rows derive
  clean against the pinned bytes with the first 48 byte-identical
  (append-only, no reorder); `E_MAP_COVER` covers the new refs
  automatically; the server refusal grep rides `E_HIT`.
- Autoplay `COMBAT=` leg mirrors the lead (teleport 2.2 east, head aim
  from the pure-parsed geo, genuine `attackTargetEntityWithCurrentItem`,
  exact-2.0 poll): 1.16.5-native player list (`ServerWorld.getPlayers`
  — no `playerEntities` field ships) and coords (`getPosX/Y/Z`);
  the strike through `PlayerEntity.attackTargetEntityWithCurrentItem`
  (`func_71059_n (Entity)V`, obf `bfw/f` — declared on
  `PlayerEntity`, not the same-named `ServerPlayerEntity` row), the
  wound poll through `LivingEntity.getHealth` (`func_110143_aJ ()F` —
  not the same-descriptor max-health sibling), the aim eye through
  `Entity.getEyeHeight` (all three SRG-anchored in autoplay
  `want.txt`).
- `PORT_QUEUE` row `Combat weakspot hook` flips to
  `live | live | e0 | TODO`.

## Addendum — port live, bridge-1165 (2026-09-11)

`bridge-1165` `531799c` (E0) + `605b623` (live fix) proves the hook
live on Forge 36.2.42 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb/llvmpipe, exit 0, host
OpenJDK 1.8.0_502):

- Server re-proof green with the 54-line map (bind clean, ticks
  clean, world == pure union 1922 cells — hook dormant, zero `E_HIT`,
  zero combat lines on the playerless dedicated server).
- Client: census 1→4 at worldTicks 2..5, then `[MatouBridge] combat
  resolved <bone=head mult=2.0 dmg=1.0->2.0>` at worldTick 500,
  `[MatouAutoplay] combat struck <head hp=20.0>` the same tick,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x head 2x),
  spawn kill at 1000 → gem carrier the same bridge tick → polled at
  1001 (elapsed 1, chain intact on the wounded beast), clean
  shutdown ; `verify-client-save.sh` world == pure union (1274 cells,
  stone) ; zero `E_*` / linkage lines in `game.log`.
- Trouvaille (owner-discipline class, same as the 1122 `posX`
  `NoSuchFieldError` fixed in `840507c`): the first play run died
  with `NoSuchMethodError: MatouEntity.getPosX()D` in
  `MatouEntity.hitBoxes` — the 1165 port called the `getPosX/Y/Z`
  getters on the `MatouEntity`-typed `this`, whose reobf walk dies at
  the vanilla `PigEntity` link (the E0 claim "rides the 1122 fix by
  construction" was wrong for this one call site — every other hook
  call already read through the declaring `Entity`). Fix
  (`605b623`): `Entity self = this`, read through `self`, mirroring
  the 1122 spelling. The crash itself proved the rest of the path
  first try (teleport, aim, genuine strike, event delivery,
   `HitTester` entry) ; crash-fast killed the run in seconds.
- `PORT_QUEUE` row `Combat weakspot hook` flips to
  `live | live | live | TODO` (1201 stays the last TODO cell, never
  silent).

## Addendum — port E0, bridge-1201 (2026-09-11)

`bridge-1201` `198e83e` ports the hook version-native, E0-green
(stages 1-2, live proof TODO — same bar as the 1122 lead E0 and the
1165 port E0): the same 11-file shape (hook + autoplay `COMBAT=` leg +
stubs + narrow map + pins + verdict), plus the owner-discipline fix
landed upfront instead of red-crashed first.

- 47.2.0-native shapes (server.txt + joined.tsrg v2 + javap measured,
  never ported blind): the hurt entity behind `LivingEvent.getEntity()`
  as `LivingEntity` (the 1.16.5 `getEntityLiving` shape does not port),
  the source behind `LivingHurtEvent.getSource()`, the true attacker
  behind `DamageSource.getEntity()` (the direct entity is the
  projectile, not the author — the same-descriptor sibling trap of the
  older `getTrueSource` ports, hence the Mojmap-name anchor); eye/look
  through the declaring `Entity` as `Vec3` (`getEyePosition` no-arg
  `()Vec3`, `getLookAngle` no-arg `()Vec3` — 1.20.1-native, no height
  arithmetic, the eye position is direct); the look/eye components on
  the declaring `Vec3` fields (`x/y/z` doubles — the same-named
  `x()/y()/z()` methods are NOT this, hence the field anchor; the 1.12
  `Vec3d` owner does not port); the dim gate stays the `OVERWORLD` key;
  `LivingHurtEvent(LivingEntity, DamageSource, float)` +
  `getSource`/`getAmount`/`setAmount` presence-pinned against the 47.2.0
  universal (Forge-added, never obfuscated).
- Narrow map 48 -> 54 rows (combat tranche, hub `tools/live-derive.sh`
  era-1.20 assert bumped in the same tranche): the 6 new rows derive
  clean against the pinned bytes with the first 48 byte-identical
  (append-only, no reorder — `getEyePosition` is `m_146892_`,
  `getLookAngle` `m_20154_`, `getEntity` `m_7639_`, `Vec3/x/y/z`
  `f_82479_/f_82480_/f_82481_`); `E_MAP_COVER` covers the new refs
  automatically; the server refusal grep rides `E_HIT`.
- Autoplay `COMBAT=` leg mirrors the lead (teleport 2.2 east, head aim
  from the pure-parsed geo, genuine strike, exact-2.0 poll):
  47.2.0-native player list (`ServerLevel.players`, same shape as the
  loot/spike helpers) and coords (`getX/Y/Z`); the teleport through
  `Entity.moveTo(DDDFF)V` (the 1.12 `setPositionAndRotation` shape does
  not port — already pinned in the live map, SRG `m_7678_` both sides);
  the strike through `Player.attack(Entity)V` (declared on `Player`,
  SRG `m_5706_` — not the same-named `ServerPlayer` row); the wound
  poll through `LivingEntity.getHealth` (SRG `m_21223_` — not the
  same-descriptor max-health sibling); the aim eye through
  `Entity.getEyeHeight` (SRG `m_20192_`, all four SRG-anchored in
  autoplay `want.txt`, 24 -> 28 rows green). Mojmap autoplay derive
  pins methods only, so the companion never reads `Vec3` fields (the
  bridge hook owns that surface).
- Owner discipline upfront (`MatouEntity.hitBoxes` through a
  declaring-`Entity`-typed self, citing `840507c` + `605b623`): the
  1201 port lands WITH the fix the 1122/1165 ports each red-crashed
   into — same bare-`getX` shape, same vanilla `Pig` link death, refused
   before the first live run instead of after.
- `PORT_QUEUE` row `Combat weakspot hook` flips to
  `live | live | live | e0`.

## Addendum — port live, bridge-1201 (2026-09-11)

`bridge-1201` `198e83e` (E0) + `a194310` (pin-loop refactor) proves
the hook live on Forge 47.2.0 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb, exit 0, host Temurin
17.0.20) — zero live fixes, the owner-discipline fix having landed
upfront in the E0:

- Server green with the 54-line map (bind clean, ticks clean, world ==
  pure union 1922 cells — hook present but dormant, zero `E_HIT`,
  zero combat lines on the playerless dedicated server).
- Client: census 1→4 at worldTicks 2..5, `spawn hp <20.0>`, then
  `[MatouBridge] combat resolved <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x head 2x, no
  crit, no fallback), spawn kill at 1000 → gem carrier at 1001
  (elapsed 1, chain intact on the wounded beast), clean shutdown ;
  `verify-client-save.sh` world == pure union (1274 cells, stone) ;
  zero `E_*` / linkage lines in `game.log` (the single `Caused by` is
  the known vanilla flite narrator `UnsatisfiedLinkError`, non-fatal —
  same signature as the 1201 renderer proof).
- 47.2.0-native shapes proven first try (no red crash, no fix
  commit): `Vec3` eye/look direct (no height arithmetic),
  `DamageSource.getEntity` as the true attacker, `Player.attack` as
  the genuine strike path, `moveTo` teleport, exact-2.0 poll. The
  upfront owner fix (`Entity self = this` in `hitBoxes`, citing
  `840507c` + `605b623`) held — no `NoSuchMethodError`, the crash
  class the two older ports each paid once never fired here.
- Trouvaille (hub tooling, same tranche): the combat E0 pushed
  `bridge-1201/tools/run-live.sh` to 452 eSLOC, tripping the hardened
  shell ceiling (hub gate, was 442 with 8 under at hardening). Fixed
  in `a194310` the same day: same pins table-driven (Vec3 fields +
  LivingHurtEvent members in loop form, every name literal), 452 →
  447, no logic change.
- `PORT_QUEUE` row `Combat weakspot hook` flips to
  `live | live | live | live` (combat hook live on 4/4 runtimes, 0
  `e0` / `TODO` remaining).

## Addendum — combat policy, lead bridge-1122 E0 (2026-09-11)

Closes the third re-opener below (attribute-driven reach +
content-driven weakspot tables): the `COMBAT_REACH = 4.0` bridge
constant and the `BeastModel.WEAKSPOTS` singleton are retired, replaced
by content-sealed policy end to end. Stages 1-2 green on the lead,
live proof TODO — same bar as every lead E0.

- Language (spi `0e1305b`): `spec/SYNTAX-V5.md` delta (frozen after
  gate) — new v5-only `Weakspot` genre, V1 types only (the instance
  name IS the bone, one required `mult : f32`; the parser stays
  syntactic, positivity/dupe/empty refused by the deciding table, same
  split as `vein.size`). The mob reach attribute stays a `Mob` field
  (`reach : f32`, no genre needed); tables join by file co-location
  (one owned file funds one mob plus its weakspots), same join as
  loot/spawn. Both parsers gain the version-gated table
  (`GENRES_V5`, header `syntax 5`); 22 goldens green both runners
  (`valid_v5_weakspot`, `err_v4_weakspot`, `err_version` bumped 5→6 —
  the V4 tranche's own mechanical share). Version gating reuses the
  existing codes (`E_MATOU_GENRE` / `E_MATOU_TYPE`, no new codes).
- SPI contract: `PolicyPack.combatWeakspots()` (insertion-ordered
  bone→mult, never null/empty, values positive finite) +
  `PolicyPack.combatReach()` (positive finite eye-to-hitVec cutoff, no
  operator override in v1 — same split as `spawnHp`: the spec field
  ships with its live reader, the override is a named follow-up).
  Only implementer is `ExamplePack` — no other tree implements the
  interface (audited by grep, not assumed).
- Content (example1 `fadee60`): `CombatTable.fromFile` (single-mob
  scope, `E_EXAMPLE_COMBAT:multi/empty`, `bad reach/mult`, `dupe`
  bone — never defaulted) + `ExamplePolicy` third table + pack
  delegates; `content/owned.matou` bumped `syntax 1`→`5` with
  `reach = 4.0` and `weakspot head mult = 2.0` — the exact retired
  values (vanilla 3.0 plus one block of bone extent, derivation moved
  from the code comment into content, zero behaviour change for the
  live proof). `ExampleCheck` covers seal values, immutability,
  wires-like-owned, the full refusal battery, pack parity on every
  wiring path, and unwired loudness; `tools/check_content.py` owned
  shape gains the fifth genre.
- Lead bridge (bridge-1122 `c1378a1`): `wireCombat` seals the table
  into `BeastModel` once at wire time and lands the reach on the
  hook's cutoff (`E_COMBAT_POLICY:unwired/null/empty` — a hit-time
  read before the seal refuses, never 1.0x); `MatouEntity` serves the
  sealed map; `onHurt` ray-tests at the sealed reach. No owned file
  means combat stays passive (Q1). Mechanical SPI re-pin on the three
  siblings (additive change, E0 green each, no live re-proof).
- `PORT_QUEUE` row `Combat policy weakspots+reach` (`BRIDGE_PARITY.md`):
  `TODO | e0 | TODO | TODO`.

## Addendum — combat policy live, lead bridge-1122 (2026-09-11)

`bridge-1122` `c1378a1` (E0, zero live fixes) proves the sealed policy
live on Forge 2860 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb/llvmpipe, exit 0, host
OpenJDK 1.8.0_502): the exact-2.0 proof now reads through content,
not constants.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells — hook present but dormant, zero `E_HIT`, zero combat lines
  on the playerless dedicated server) with `combat wired
  <{head=2.0}> reach <4.0>` sealed from the owned file at wire time.
- Client: `combat wired <{head=2.0}> reach <4.0>`, census 1→4 at
  worldTicks 2..5, `spawn hp <20.0>`, then `[MatouBridge] combat
  resolved <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x sealed head
  2x, no crit, no fallback), natural adopt/sweep/replacement at 69
  (same signature as the T4 proofs), spawn kill at 1000 → gem
  carrier at tick 999 → polled at 1001 (elapsed 1, chain intact),
  clean shutdown at 4600 ticks ; `verify-client-save.sh` world ==
  pure union (1274 cells) ; zero `E_*` / linkage lines in `game.log`
  (two benign client model-bake `Caused by` for the registered gem
  item — missing `models/item/my_gem.json`, non-fatal, game runs to
  clean shutdown and the verdict stays green).
- `PORT_QUEUE` row `Combat policy weakspots+reach` flips to
  `TODO | live | TODO | TODO` (lead live, three ports TODO, the
  `E_COMBAT_POLICY` local-code gap names them).

## Addendum — combat policy port, bridge-1710 (2026-09-11)

`bridge-1710` `2b74075` (E0, zero live fixes) proves the sealed policy
live on Forge 1614 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb/llvmpipe, exit 0, host
OpenJDK 1.8.0_502): the exact-2.0 proof now reads through content,
not constants — same 4-file shape as the 1122 lead E0, 1614-native
throughout (no narrow-map delta: the hook already rides the
1614-native `getEntity` / `Vec3.xCoord` spelling, the policy wire is
era-blind).

- Stages 1-2 green on the port (`tools/check.sh`: `ModelWireCheck`
  sealed 2x, forge-stub + autoplay-compile) ; SPI already pinned at
  `0e1305b` (mechanical re-pin landed ahead, additive).
- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,165 — hook present but dormant, zero `E_HIT`, zero
  combat lines on the playerless dedicated server) with `combat wired
  <{head=2.0}> reach <4.0>` sealed from the owned file at wire time.
- Client: `combat wired <{head=2.0}> reach <4.0>`, census 1→4 at
  worldTicks 2..5, `spawn hp <20.0>`, then `[MatouBridge] combat
  resolved <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x sealed head
  2x, no crit, no fallback), natural adopt/sweep/replacement at
  49/69 (same signature as the T4 proofs), spawn kill at 1000 → gem
  carrier at tick 999 → polled at 1001 (elapsed 1, chain intact),
  clean shutdown at 4600 ticks ; `verify-client-save.sh` world ==
  pure union (1274 cells, stone) ; zero `E_*` / linkage lines in
  `game.log` (one benign Forge Version Check `Caused by` — offline
  version JSON fetch, non-fatal — plus one benign `TEXTURE ERRORS
  MISSING_ICON_ITEM_4096_my_gem.png` for the registered gem item,
  non-fatal, game runs to clean shutdown and the verdict stays
  green).
- `PORT_QUEUE` row `Combat policy weakspots+reach` flips to
  `live | live | TODO | TODO` (two ports live, two TODO, the
  `E_COMBAT_POLICY` local-code gap names the remaining two).

## Addendum — combat policy port, bridge-1165 (2026-09-11)

`bridge-1165` `17d41a8` (E0, zero live fixes) proves the sealed policy
live on Forge 36.2.42 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb, exit 0, host OpenJDK
1.8.0_502): the exact-2.0 proof now reads through content, not
constants — same 4-file shape as the 1122 lead E0, 36.2.42-native
throughout (no narrow-map delta: the hook already rides the
`getEntityLiving` / `getTrueSource` / declaring-`Entity` / `Vector3d`
spelling, the policy wire is era-blind).

- Stages 1-2 green on the port (`tools/check.sh`: `ModelWireCheck`
  sealed 2x, forge-stub + autoplay-compile) ; SPI already pinned at
  `0e1305b` (mechanical re-pin landed ahead, additive).
- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ore + stone names — hook present but dormant, zero `E_HIT`,
  zero combat lines on the playerless dedicated server) with `combat
  wired <{head=2.0}> reach <4.0>` sealed from the owned file at wire
  time.
- Client: `combat wired <{head=2.0}> reach <4.0>`, census 1→4 at
  worldTicks 1..4, `spawn hp <20.0>`, then `[MatouBridge] combat
  resolved <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x sealed head
  2x, no crit, no fallback), natural adopt/sweep/replacement at
  49/69 (same signature as the T4 proofs), spawn kill at 1000 → gem
  carrier the same bridge tick → polled at 1001 (elapsed 1, chain
  intact), clean shutdown (exit 0) ; `verify-client-save.sh` world ==
  pure union (1274 cells, stone) ; zero `E_*` / linkage / `Caused by`
  lines in `game.log` (one benign `ModelBakery` missing
  `example1:models/item/my_gem.json` WARN for the registered gem
  item plus one benign vanilla Narrator `fliteWrapper` ERROR,
  both non-fatal, game runs to clean shutdown and the verdict stays
  green).
- `PORT_QUEUE` row `Combat policy weakspots+reach` flips to
  `live | live | live | TODO` (three ports live, one TODO — 1201
  remains, the `E_COMBAT_POLICY` local-code gap names it).

## Addendum — combat policy port, bridge-1201 (2026-09-11)

`bridge-1201` `3712673` (E0, zero live fixes) proves the sealed policy
live on Forge 47.2.0 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb, exit 0, host Temurin
17.0.20): the exact-2.0 proof now reads through content, not
constants — same 4-file shape as the 1122 lead E0, 47.2.0-native
throughout (no narrow-map delta: the hook already rides the
`getEntity` / `getEntity` / declaring-`Entity` / `Vec3` direct
spelling, the policy wire is era-blind).

- Stages 1-2 green on the port (`tools/check.sh` 186 ok:
  `ModelWireCheck` sealed 2x, forge-stub + autoplay-compile) ; SPI
  already pinned at `0e1305b` (mechanical re-pin landed ahead,
  additive).
- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ore + stone names — hook present but dormant, zero `E_HIT`,
  zero combat lines on the playerless dedicated server) with `combat
  wired <{head=2.0}> reach <4.0>` sealed from the owned file at wire
  time.
- Client: `combat wired <{head=2.0}> reach <4.0>`, census 1→4 at
  worldTicks 2..5, `spawn hp <20.0>`, then `[MatouBridge] combat
  resolved <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x sealed head
  2x, no crit, no fallback), spawn kill at 1000 → gem carrier the
  same bridge tick → polled at 1001 (elapsed 1, chain intact), clean
  shutdown (exit 0) ; `verify-client-save.sh` world == pure union
  (1274 cells, stone) ; zero `E_*` / linkage lines in `game.log`
  (the single `Caused by` is the known vanilla flite narrator
  `UnsatisfiedLinkError`, non-fatal — same signature as the 1201
  renderer proof and the hook live proof, game runs to clean
  shutdown and the verdict stays green).
- `PORT_QUEUE` row `Combat policy weakspots+reach` flips to
  `live | live | live | live` (four ports live, 0 `TODO` remaining —
  the `E_COMBAT_POLICY` local-code gap is closed).

## Addendum — combat reach override, lead bridge-1122 E0 (2026-09-11)

Closes the operator-override half of the third re-opener below (the
content half already closed by the policy E0): the sealed content reach
gains an operator win, same split as the `SPAWN.md` operator-override
tranche. Stages 1-2 green on the lead, live proof TODO — same bar as
every lead E0.

- Lead bridge (bridge-1122): `OperatorPolicy` gains the `combat.reach`
  key (positive finite f64, `COMBAT_REACH`) with `effectiveCombatReach`
  (absent means content, present wins, bad/multi/unknown refuse loudly
  under the new `E_COMBAT_WIRE` code — declared here, so the parity dim-4
  gap names it on the three siblings, never silently) ; `wireCombat`
  seals the effective reach and logs `overridden <combat.reach>` on
  override (same suffix shape as the spawn/loot wires). Weakspot
  multipliers stay content-only (damage balance, same split as
  `spawnHp` — no operator key, never a quiet knob). No SPI change, no
  re-pin (bridge-owned operator domain) ; no new `forge/src` file, no
  new `E_FORGE_*`.
- Gate: `ModelWireCheck` gains the reach-override battery (content 4.0
  read from `../example1/content/owned.matou`, absent-means-content,
  5.0 win, present/absent, zero/negative/non-numeric/NaN/Infinity/
  multi/unknown/null refusals) — same shape as the spawn/loot
  batteries, no new gate. `tools/check.sh` exit 0 (etages 1-2, live
  skipped).
- `PORT_QUEUE` row `Combat reach override` (`BRIDGE_PARITY.md`):
  `TODO | e0 | TODO | TODO`.

## Addendum — combat reach override live, lead bridge-1122 (2026-09-11)

`bridge-1122` `81ccc46` (E0, zero live fixes) proves the override live
on Forge 2860 (150 s server + two launcher-free headless direct-client
`SPAWN=1 COMBAT=1` legs, Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502):

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — hook present but dormant, zero `E_HIT`, zero
  combat lines on the playerless dedicated server) with `combat wired
  <{head=2.0}> reach <4.0>` sealed from the owned file (no suffix —
  the default leg pins the un-overridden line byte-shape).
- Client default leg: `combat wired <{head=2.0}> reach <4.0>`, then
  `[MatouBridge] combat resolved <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — the exact-2.0 assert, bare-hand 1.0 x sealed head
  2x, no crit, no fallback).
- Client override leg (operator act: `combat.reach=5.0` appended to the
  staged `packs.cfg` wire line, same single line, no script edit):
  `combat wired <{head=2.0}> reach <5.0> overridden <combat.reach>`
  (the operator win lands on the hook cutoff and names itself),
  identical exact-2.0 (`struck <head hp=20.0>` at 500, `resolved
  <drop=2.0 hp=18.0>` at 501, elapsed 1 — the wider cutoff changes
  nothing at 2.2 blocks, as designed).
- Both client legs: `verify-client-save.sh` world == pure union (1274
  cells) ; zero `E_*` / linkage lines in `game.log` (the same two
  benign client model-bake `Caused by` for the registered gem item as
  the policy live proof — missing `models/item/my_gem.json`,
  non-fatal).
- `PORT_QUEUE` row `Combat reach override` flips to
  `TODO | live | TODO | TODO` (lead live, three ports TODO, the
  `E_COMBAT_WIRE` local-code gap names them).

## Addendum — combat reach override ports, 1710/1165/1201 (2026-09-11)

Three parallel port tranches, all live-green first try, zero live
fixes — the policy wire confirmed era-blind on each (lead
pre-tranche `OperatorPolicy.java` + `ModelWireCheck.java`
byte-identical, `wireCombat` hunk identical, applied as the exact lead
diff; no narrow-map delta, no SPI change, no re-pin, no new
`forge/src` file, no new `E_FORGE_*`):

- `bridge-1710` `3e6338e` (Forge 1614, Java 8 host, `B3_OFFLINE=1`) :
  150 s server green (`combat wired <{head=2.0}> reach <4.0>`, world
  == pure union 1922 cells, ids 1,165, zero `E_*`/linkage) ; client
  default leg exact-2.0 (500→501, elapsed 1) ; client override leg
  (`combat.reach=5.0` appended to the staged `packs.cfg`) `reach
  <5.0> overridden <combat.reach>` with identical exact-2.0 ; both
  saves pure union 1274 cells. Single benign `Caused by` (offline
  Forge Version Check fetch, non-fatal — same signature as the policy
  proof).
- `bridge-1165` `d07caeb` (Forge 36.2.42, `E3_OFFLINE=1`) : 150 s
  server green (`reach <4.0>`, 1922 cells ore + stone, zero
  `E_*`/linkage) ; default leg exact-2.0 with census 1→4 at ticks
  2..5 ; override leg `reach <5.0> overridden <combat.reach>` with
  identical exact-2.0 ; both saves 1274 cells, zero `E_*`/linkage/
  `Caused by`.
- `bridge-1201` `bf3d865` (Forge 47.2.0, Temurin 17 host) : 150 s
  server green (`reach <4.0>`, 1922 cells, zero `E_*`/linkage) ;
  default leg exact-2.0 with census 1→4 at ticks 2..5 ; override leg
  `reach <5.0> overridden <combat.reach>` with identical exact-2.0 ;
  both saves 1274 cells, zero `E_*`/linkage (single benign vanilla
  flite-narrator `Caused by`, same signature as prior 1201 proofs).
- Trouvaille (live ops, no code impact): all four Forge servers bind
  the same 25565 port, so parallel port runs serialize on the server
  leg — the 1710/1165 agents each waited out a sibling bind and
  stayed green. Ports stay parallel-safe on code, sequential on boot.
- `PORT_QUEUE` row `Combat reach override` flips to
  `live | live | live | live` (four ports live, 0 `TODO` remaining —
  the `E_COMBAT_WIRE` local-code gap is closed).

## Addendum — combat per-mob tables, lead bridge-1122 E0 (2026-09-11)

Opens the per-mob line of the third re-opener below (loot/spawn
keep their co-location single-mob joins, the second beast class
stays a follow-up): every combat weakspot now funds one
`(mob, bone)` pair end to end. Stages 1-2 green on the lead, live
proof TODO — same bar as every lead E0.

- Language (spi `bb8c9f5`): `spec/SYNTAX-V6.md` delta (frozen after
  gate) — `Weakspot` gains required `mob : mob_ref` (a V1-valid
  type, so no new genre, type or code); v6 weakspot duplicates key
  on `(mob, bone)` at decide time (every beast has a `head`), so
  the header-time `(decl, name)` check is skipped for v6 weakspots
  in both parsers (symmetric py+java). V5 files keep the
  co-location single-mob path (multi still refuses, a
  `mob`-carrying weakspot in v5 refuses); a mob-less weakspot in
  v6 refuses. Goldens: `valid_v6_weakspot` (two mobs sharing
  `head`), `err_version` bumped 6→7 (the V5 tranche's own
  mechanical share).
- SPI contract: `PolicyPack.combatMobs()` (insertion-ordered, never
  empty) + `combatWeakspots(mob)` / `combatReach(mob)` (loud on
  null/unknown mob); `combatWeakspots()` / `combatReach()` stay as
  sole-mob views (loud unless exactly one mob is sealed — never a
  quiet pick). Only implementer is `ExamplePack` (audited by grep,
  not assumed).
- Content (example1 `1917963`): `CombatTable` seals per-mob maps
  (short mob names, insertion-ordered, two passes so forward refs
  resolve) with the V5 path intact; V6 refusals (`no mob`,
  `unknown mob`, `lonely mob`, `(mob, bone)` dupe) stay under the
  kept `E_EXAMPLE_COMBAT` family. `content/owned.matou` bumped
  `syntax 5`→`6` with `mob = example1.content:my_beast` on the head
  row — the exact sealed values (reach 4.0, head 2.0, zero
  behaviour change for the live proof). `ExamplePolicy` plus pack
  delegates; `ExampleCheck` gains the per-mob battery (two-mob tmp
  seals, V5 compat, all V6 refusals).
- Lead bridge (bridge-1122 `50af816`): `BeastModel.sealCombat`
  replaces `sealWeakspots` (one seal truth, per-mob maps
  re-validated under the kept `E_COMBAT_POLICY` family, no new
  `forge/src` file, no new `E_FORGE_*`); the legacy
  `combatWeakspots()` derives the sole entry. `wireCombat` seals
  per-mob from the policy mobs and keeps the effective sole reach
  plus the byte-identical `combat wired <{head=2.0}> reach <4.0>`
  line; `onHurt`, `MatouEntity`, `OperatorPolicy` untouched (no
  narrow-map delta: the policy wire stays era-blind). Mechanical
  SPI re-pin on the three siblings (additive, E0 green each, no
  live re-proof).
- `PORT_QUEUE` row `Combat per-mob tables` (`BRIDGE_PARITY.md`):
  `TODO | e0 | TODO | TODO`.

## Addendum — combat per-mob tables live, lead bridge-1122 (2026-09-11)

`bridge-1122` `50af816` (E0, zero live fixes) proves the per-mob
seal live on Forge 2860 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, Xvfb/llvmpipe, exit 0, host
OpenJDK 1.8.0_502): the exact-2.0 proof now reads through the
per-mob seal, one mob sealed.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — hook present but dormant, zero `E_HIT`, zero
  combat lines on the playerless dedicated server) with
  `combat wired <{head=2.0}> reach <4.0>` sealed per-mob at wire
  time (no suffix — byte-identical to the pre-per-mob shape).
- Client: same wired line, census 1→4 at worldTicks 2..5,
  `spawn hp <20.0>`, then `[MatouBridge] combat resolved
  <bone=head mult=2.0 dmg=1.0->2.0>`,
  `[MatouAutoplay] combat struck <head hp=20.0>` at worldTick 500,
  `[MatouAutoplay] combat resolved <drop=2.0 hp=18.0>` at worldTick
  501 (elapsed 1 — bare-hand 1.0 x sealed head 2x, no crit, no
  fallback), kill 1000 → carrier at tick 999 → polled at 1001
  (elapsed 1, chain intact) ; `verify-client-save.sh` world == pure
  union (1274 cells) ; zero `E_*` / linkage lines in `game.log`
  (two benign client model-bake `Caused by` for the registered gem
  item, same signature as the policy proof).
- Trouvaille (live ops, no code impact): the staged instance kept
  the previous tranche's `combat.reach=5.0` in its `packs.cfg`
  (keep-then-stage pattern), so the first client run logged the
  override leg — exact-2.0 held there too, then a documented reset
  (drop the staged `packs.cfg`, re-stage) re-ran the clean default
  leg above. Staged knobs survive tranches; the reset path is the
  fix, never a code change.
- `PORT_QUEUE` row `Combat per-mob tables` flips to
  `TODO | live | TODO | TODO` (lead live, three ports TODO).

## Addendum — combat per-mob tables ports, 1710/1165/1201 (2026-09-11)

Three parallel port proofs, all live-green first try, zero live
fixes — the per-mob seal confirmed era-blind on each (siblings
carry only the mechanical SPI re-pin, no code change; no
narrow-map delta, no new `forge/src` file, no new `E_FORGE_*`):

- `bridge-1710` `2540e98` (Forge 1614, Java 8 host, `B3_OFFLINE=1`) :
  150 s server green (`combat wired <{head=2.0}> reach <4.0>`, world
  == pure union 1922 cells, ids 1,165, zero `E_*`/linkage) ;
  client default leg exact-2.0 (500→501, elapsed 1, kill 1000 →
  carrier 999 → polled 1001) ; save pure union 1274 cells. Single
  benign `Caused by` (offline Version Check) plus the known benign
  gem-icon texture error. Same staged-`packs.cfg` override-leg
  incident as the lead (reset via the documented path, no code
  impact).
- `bridge-1165` `bd61ba2` (Forge 36.2.42, `E3_OFFLINE=1`) : 150 s
  server green (`reach <4.0>`, 1922 cells ore + stone, zero
  `E_*`/linkage, two 25565 bind-races retried green) ; default leg
  exact-2.0 with census 1→4 at ticks 1..4, kill 1000 → carrier
  same tick → polled 1001 ; save 1274 cells, zero `E_*`/linkage/
  `Caused by` (one benign `ModelBakery` gem WARN plus one benign
  vanilla Narrator `fliteWrapper` ERROR, both non-fatal).
- `bridge-1201` `b2328a3` (Forge 47.2.0, Temurin 17 host,
  `D3_OFFLINE=1`) : 150 s server green (`reach <4.0>`, 1922 cells,
  54-line map, zero `E_*`/linkage, two 25565 bind-races retried
  green) ; default leg exact-2.0 with census 1→4 at ticks 2..5,
  kill 1000 → carrier 999 → polled 1001 ; save 1274 cells, zero
  `E_*`/linkage (single benign vanilla flite-narrator `Caused
  by`). `run-live.sh` untouched at 447 eSLOC (3 under the
  ceiling).
- `PORT_QUEUE` row `Combat per-mob tables` flips to
  `live | live | live | live` (four ports live, 0 `TODO`
  remaining — per-mob sealed on 4/4 runtimes with one mob; the
  second beast class stays the named follow-up).

## Error catalog — completion (same tranche)

The SPI `HitCheck` suite already proves refusals the original catalog
above did not name: `E_HIT_VEC:nan`, `E_HIT_VEC:null` (`Vec3d`
construction and arithmetic), `E_HIT_BONE:empty` (blank bone name),
`E_HIT_BOX:null` (null box), `E_HIT_BOXES:null` (null target list),
`E_HIT_DIST:negative_or_nan` (`RayHit` distance). Named here so the
catalog matches the code — no SPI change, no re-pin, the bridge hook
can surface `E_HIT_VEC:nan` / `E_HIT_DIR:zero` on corrupt attacker
state and stay inside the declared set.

## What would re-open it

- BUG-042 reach override: an `AttackEntityEvent` hook allowing limb
  hits the vanilla origin-distance veto never delivers (this hook
  only refines delivered hurts).
- Client prediction + attack packet with server re-ray-test and
  tolerance check (the §3 lifecycle as specified above).
- Combat policy follow-ups (not silent): policy live x4 and reach
  override live x4 (rows above, both closed); per-mob tables live
  x4 (rows above — one mob sealed on 4/4 runtimes, zero behaviour
  change); second beast class, per-mob operator override and
  loot/spawn per-mob stay named follow-ups (single-table scope
  holds there); MC-`AttributeInstance` reach stays
  refused — the content `reach` field IS the attribute-driven
  reading (one SPI number, four identical wires, no per-version
  attribute call-site to drift).
