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
- Attribute-driven reach (replacing `COMBAT_REACH`) and
  content-driven weakspot tables (replacing the beast-local 2x).
