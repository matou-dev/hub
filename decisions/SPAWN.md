---
type: spec
status: active
maturity: standard
scope: shared
roadmap: -
---

# Spawn — event-sourced mob placement on the repop seam

Date: 2026-09-10
Status: active (first consumer: example1 `SpawnJob`/`SpawnTable` + bridge-1710 live wire, live-proven 2026-09-10)

## Problem

`mob my_beast` (`hp`, `drop`) is declared in
`example1/content/owned.matou` and spawned nowhere: no spawn kernel
in `spi`, no `EntityJoinWorld`/spawn hook in any bridge, no census,
no cap. World population today is static placement only (veins,
scatter, structures). A beast the loot table pays out for must first
exist in the world through a pure decision.

## Decision

Event-sourcing, repop-seam shape (`decisions/REPOP_SPIKE.md`: store ->
seal -> pure decide -> land, tripwire on live divergence):

- `SpawnStore` (bridge-owned, plain data, zero MC): per-tick census
  (`record` living beasts by chunk/cell, `claimDue` for budgeted
  spawns, `sealed()` copy).
- Forge hooks (bridge `forge` package only, Q2 holds):
  `TickEvent.WorldTickEvent` server-side END dim-0 census + budget
  tick (the same tick that already drives `PackWire` apply and the
  spike seal), plus an `EntityJoinWorldEvent` veto when the pure
  decision says the cap is reached. Same dim-0-first scoping as the
  spike; other dims out of scope, not errors.
- `SpawnSeal` (pure) seals the census beside `pack.states` through
  `ForgeSnapshot.snapshot` — SPI untouched, no `decideAll` change, no
  re-pin (spike decoration answer, third use).
- `SpawnJob` (pure, `MatouJob` contract): reads spawn-table states
  (mob ref, cap, count/tick budget, y-range) plus the sealed census,
  emits spawn decisions (cell + mob ref). Missing/wrong-typed states
  refuse loudly (`E_SPAWN_*`), never defaulted.
- Landing: the bridge converts due spawns to
  `world.spawnEntityInWorld` through a version-native sink. A live
  `claimed != due` divergence fails the tick loudly
  (`E_SPAWN_SEAL:diverged`).

Data constraint: same as loot — V1's 4 genres stay frozen, spawn
rides `mob` refs plus minimal spawn fields in the V4-delta family
(cap, count, where). Tranche 1 spawns a vanilla host entity id
carrying our loot table (zero registration risk); a custom entity
class follows the `decisions/REGISTRATION.md` path later (landed —
see the custom entity tranche below) and gets its own addendum. Codes `E_SPAWN_*` tranche-local in the existing
`MatouBridgeMod.java`; `check-bridges.sh` parity holds 1710-only
until proven.

Explicit non-goals for tranche 1: custom entity rendering, biome /
dimension filters, despawn policy, pack AI.

## Landed shape (tranche 1, live-proven 2026-09-10)

- `example1` (`SpawnJob` + `SpawnTable`, E0 `ExampleCheck` green):
  `SpawnJob` is stateless like `LootJob` and reads
  `example1.spawn:census` (entity-id to spawn cell) + `:table` (content
  mob ref) + `:cap` (Counts-style trio under `E_SPAWN_CAP`) +
  `:budget` (Counts-style trio under `E_SPAWN_BUDGET`) + `:y`
  (`[yMin, yMax]` longs under `E_SPAWN_Y`) from the snapshot, emitting
  `min(budget, max(cap - census, 0))` spawn cells with the content mob
  ref at seeded pads (GRID x/z, sealed y band). `SpawnTable.fromFile`
  seals the single mob ref (`namespace:name`) — 0/N mobs refuse loudly
  (single-table scope). `ExamplePack` untouched (no new job branch, the
  seal wires beside it like loot).
- `bridge-1710` (`fr.iamacat.bridge.spawn`, E0 `SpawnCheck` green):
  `SpawnStore` (record/release/slotsDue, entity-id census, unknown
  release is false) + `SpawnSeal.seal(store, mob, cap, budget, yMin,
  yMax)` beside the first wire's pack states (SPI untouched, no re-pin)
  + comparateur (budgeted slots equal the job decision size, budgets
  1..2).
- Forge wire (`MatouBridgeMod`, `E_SPAWN_*` local, parity holds):
  `SPAWN_CAP=4` + `SPAWN_BUDGET=1` + `SPAWN_YMIN=66`/`SPAWN_YMAX=68`
  policy constants (spike `REPOP_DELAY` shape), `wireSpawn` from the
  same owned file as loot, `spawnTick` with the `E_SPAWN_SEAL:diverged`
  tripwire on slots-vs-decided, pig landing sink beside vanilla
  behaviour. Landing plus veto stay passive unless `SPAWN=1` (same
  opt-in as the companion proofs — always-on landing would veto the
  loot proof's own pig once the census fills).
- Census discipline (amended live, second red run): the join event only
  is not the census. `onJoin` records every let-through join and vetoes
  past cap, `onKill` releases pig ids, but a per-tick `reconcile` polls
  the loaded pigs and adopts/sweeps the difference before sealing — the
  sealed census is the polled living reality, never the event trail
  alone. Tranche-1 scope: pigs outside the loaded set sweep (the proof
  world keeps them loaded; a rejoin re-adopts next tick).
- Live proof (`SPAWN=1` direct client, Forge 1614, host OpenJDK
  1.8.0_502): 4 landings at ticks 0..3 (census 4 at worldTick 5, cap),
  natural pig adopted at tick 49, fallen pig swept + replacement landed
  at 69, 48 natural joins vetoed past cap, companion kill at worldTick
  1000 → diamond carrier at 1001 (elapsed 1, immediate — the loot table
  pays the chain), replacement landed at 999 after the kill release.
  Clean shutdown exit 0 after 4600 server ticks, world == pure union
  (1274 cells, ids 1,165 — legacy ore-wire pack, beasts are entities).
  E0: `ExampleCheck` spawn battery green, `SpawnCheck`
  store-vs-job comparateur green, stub compile + SRG/universal pins +
  companion derive green on both sides, no SPI change (no re-pin),
   parity holds over 4 bridges (no new forge file, `E_SPAWN_*` local).
   Thrown set (PORT_QUEUE-declared, `decisions/BRIDGE_PARITY.md`):
   `E_SPAWN_SEAL:diverged` (tripwire), `E_SPAWN_HP:diverged` (attribute
   read-back), `E_SPAWN_SPAWN:refused` (vetoed landing),
   `E_SPAWN_STORE` (`SpawnStore` args/range), `E_SPAWN_WIRE` (operator
   cap/budget/y transport).

## Measured findings

- Dead beasts linger in the loaded list: the first live run counted a
  corpse past cap at worldTick 51 and failed loud (`E_SPAWN_PROOF`,
  never silent). The companion census counts living pigs only
  (`isDead`, searge-pinned like every vanilla member).
- Natural spawns bypass `EntityJoinWorldEvent` on Forge 1614 (measured:
  a grass spawn joined with no event while the census was full — no
  veto line, second live run failed loud on the fifth living pig). The
  event stays as fast path + veto, but only the per-tick poll adopts
  every path — events alone undercount reality. The veto itself is
  proven (48 natural joins refused past cap in the green run).
- Bridge pigs fall off the union plane (pads y 66..68, plane only
  18x18): one fell 60 blocks and died on the grass at tick 49 — which
  proved the death→loot→release→respawn chain live instead of breaking
  the proof.
- ModClassLoader negative cache + verifier eager loading + file-order
  construction (measured: the first custom-entity run died `UE
  matouautoplay + UE matoubridge, UC example1` with a CNFE for a class
  sitting in its own jar). FML constructs containers file by file
  (`addFile` then `Class.forName` on a ModClassLoader with a negative
  cache cleared per container for its own ASM class list only —
  measured by javap on the provisioned 1614 universal), and the HotSpot
  verifier loads frame-named classes (`new`/`instanceof`/`checkcast`
  of `MatouEntity` all over the companion) at `forName` time —
  literals (`X.class`, example1's only use) never trigger the load.
  matouautoplay constructs before matoubridge (alpha order), so the
  beast class missed while its jar was still unsourced, the miss
  poisoned the negative cache, and the bridge died for it. Fix: the
  companion declares the real dependency
  (`required-after:matoubridge`, load-bearing — removing it re-arms
  the exact crash). Rule for this org: a mod constructed before
  another mod's jar is sourced must not verifier-reference
  (frame-name) the other jar's classes; same-jar refs are always safe
  (`addFile` precedes `forName` in the same `constructMod`).
- Vanilla ctor shapes are measured, never recalled: the pig renderer
  takes the saddle pass (`RenderPig(ModelBase, ModelBase, float)` —
  notch `boo` javaps as `(bhr, bhr, float)` from the ForgeGradle 1614
  cache; the remembered 2-arg `RenderLiving` shape died loudly with
  `NoSuchMethodError` at the first tracked spawn). `ModelPig` ctors
  `()` + `(float)` measured the same way (notch `bhu`).

## Custom entity tranche (live-proven 2026-09-10)

Tranche 1 landed beasts as vanilla pigs (zero registration risk). This
tranche registers the one generic beast and lands it instead — same
seam, same budget math, no pure change (`SpawnJob`, `SpawnTable`,
`SpawnStore`, `SpawnSeal` untouched; `ExamplePack` untouched):

- `bridge-1710` (`fr.iamacat.bridge.forge`, E0 green,
  `00a8ee8`): `MatouEntity` (final, extends `EntityPig` — pig shape,
  AI and sounds reused, no per-content subclass, no shadow field;
  vanilla pig health kept, the content `hp` rides the spec unapplied
  until the attribute seam) + `Example1Mod` preInit
  `EntityRegistry.registerModEntity` (short mob name from the
  single-mob `SpawnTable`, mod-local id 0, pig-like tracking 64/1/true
  — constants, never defaults) with an init-time `lookupModSpawn`
  tripwire plus a `registered-entity` log line + client-only vanilla
  `RenderPig` mapping (`@SideOnly`, stripped on servers) until the
  custom-renderer tranche.
- Census discipline: every `EntityPig` match becomes a `MatouEntity`
  match (`onJoin` veto, `reconcile` poll, `onKill` release,
  `landBeast` sink). Vanilla pigs are a different species now:
  ignored, never vetoed, never counted — the 48 past-cap vetos of the
  pig run are gone with the species they policed.
- Companion (`tools/autoplay`, DEV-only): counts/kills `MatouEntity`
  only (same species rule — a wandering vanilla pig would breach a cap
  that is not its own or take the scripted kill dishonestly); the loot
  leg kills the registered beast too (the LOOT.md "until the custom
  entity lands" expiry is spent — every kill still pays the single
  entry, per-mob filtering stays a re-opener). Carries
  `required-after:matoubridge` (load-bearing — see findings).
- Parity: 1710-only behavior, `E_REG_*`/`E_SPAWN_*` local (no new
  `E_FORGE_*`); same-basename zero-import `MatouEntity` shells in
  1122/1165/1201.
- Live proof (`SPAWN=1` direct client, Forge 1614, host OpenJDK
  1.8.0_502): 4 landings at ticks 0..3 (census 4 at worldTick 5, cap),
  natural beast adopted at tick 49, swept + replacement landed at 69,
  companion kill at worldTick 1000 → diamond carrier at 1001 (elapsed
  1, immediate — the loot table pays the chain), clean shutdown exit 0
  after 4600 server ticks ; world == pure union (1274 cells, ids
  1,165 — legacy ore-wire pack, `NUMERIC_IDS=example1:my_ore=165`
  from the boot log, block id stable across the entity registration).

## Gates (will prove the tranche)

- E0 pure green: `SpawnStore` census semantics, seal isolation, cap
  boundary (cap reached = no spawn, never negative), refusals,
  comparateur, etage 1.
- Live-build replica green: new event pins resolved, reobf-verified.
- Live proof green on Forge 1614: beasts appear up to cap at decided
  cells, kills pay out through the loot table
  (`decisions/LOOT.md`), world == pure union otherwise.

 ## What would re-open it

 - Custom entity class: landed (this file — class + registration +
   pig-renderer mapping). Custom RENDERER (model/animation) still open,
   same seam.
 - Content `hp`: landed (hp tranche below — the attribute seam applies
   the spec hp to the beast, read back tripwired).
  - Filters (biome, light, depth) and despawn: new pure fields +
    gate, addendum here.
  - State-id vocabulary: landed (hub
    decisions/SPI_STATE_VOCABULARY.md — seals resolve the pack-served
    vocabularies through the SPI registry, no bridge-to-content
    compile edge in the pure seal; the Mod keeps table/job/kind
    imports — T4 pack-driven re-opener, same file).

 ## HP tranche (live-proven 2026-09-10)

 The custom entity tranche kept vanilla pig health with the content
 `hp = 20` riding the spec unapplied. This tranche applies it — same
 seam, same budget math, no `SpawnJob`/`SpawnStore`/`SpawnSeal` change:

 - `example1` (`SpawnTable`, E0 `ExampleCheck` green): the table seals
   the mob `hp` beside the ref (`hp()` accessor, positive u32 —
   missing/non-positive refuses loudly under `E_EXAMPLE_SPAWN`, never
   defaulted). The missing-hp refusal surfaces through the parser
   (`unreadable (missing hp)`), still loud either way.
 - `bridge-1710` (`MatouBridgeMod`, E0 green): `wireSpawn` seals
   `spawnHp` once beside `spawnMob` (parse-once, never on the tick
   path); `landBeast` lands it on the beast's max-health attribute
   before the spawn (`getEntityAttribute(maxHealth).setBaseValue` +
   `setHealth`, all calls through the declaring stub types per owner
   discipline) and the read-back is tripwired (`E_SPAWN_HP:diverged`
   fails the tick — an underpowered beast never roams silently).
 - Stubs/pins: `EntityLivingBase` gains `getEntityAttribute` /
   `getMaxHealth` / `setHealth`, plus new `IAttribute` /
   `IAttributeInstance` / `SharedMonsterAttributes` stubs (all pinned
   in `run-live.sh` against the 1614 SRG, reobf-verified to
   `func_110148_a` / `func_110138_aP` / `func_70606_j` /
   `func_111128_a` / `field_111267_a`, zero MCP names left).
 - Companion (`tools/autoplay`, DEV-only): polls the first living
   beast's `getMaxHealth` once against a mirrored `SPAWN_HP` (pinned
   in `want.txt`, reobf-verified to `func_110138_aP`) — a diverged
   read-back fails the proof loudly here too. The scripted kill stays
   simulated (`setDead` + `LivingDropsEvent` post): damage-soak proof
   is an explicit non-goal, the seam owns the attribute value.
 - Parity: 1710-only behavior, `E_SPAWN_*` local (no new `E_FORGE_*`,
   no new `forge/src` file); `MatouEntity` ctor unchanged, sibling
   shells untouched.
 - Live proof (`SPAWN=1` direct client, Forge 1614, host OpenJDK
   1.8.0_502): `spawn wired <example1.content:my_beast> hp <20>`,
   `spawn hp <20.0>` at worldTick 2, census 4 at worldTick 5, kill at
   worldTick 1000 → diamond carrier at 1001 (elapsed 1, immediate),
   clean shutdown exit 0 after 4600 server ticks ; world == pure
   union (1274 cells, ids 1,165 — `NUMERIC_IDS=example1:my_ore=165`
   from the boot log).

  ## Measured findings (hp tranche)

  - Stubs must match the runtime kind, not just the name: the first
    live run died `IncompatibleClassChangeError: Found interface
    IAttributeInstance, but class was expected` at the first landing —
    the vanilla attribute instance is an interface, so the stub is an
    interface and the landing links through `invokeinterface`. The
    crash named the exact kind mismatch, loudly, never silently.

  ## Content-decides tranche (live-proven 2026-09-10)

  The hp tranche left five spawn numbers bridge-owned
  (`SPAWN_CAP`/`SPAWN_BUDGET`/`SPAWN_YMIN`/`SPAWN_YMAX` constants) plus
  the loot count (`LOOT_COUNT`) — the bridge named content decisions.
  This tranche moves them author-side, same seam, same budget math, no
  `SpawnJob`/`SpawnStore`/`SpawnSeal` change:

  - `example1` (`owned.matou` Mob genre + `SpawnTable`/`LootTable`, E0
    `ExampleCheck` green): the mob seals `cap` + `budget` + `y_min` /
    `y_max` + `drop_count` beside `hp`/`drop` (positive u32 each,
    `0 <= y_min <= y_max` — missing/zero/unordered refuses loudly
    under `E_EXAMPLE_SPAWN`/`E_EXAMPLE_LOOT`, missing fields surfacing
    through the parser, still loud). Proof values unchanged (4/1/66..68
    and count 1 — the companion mirrors stay green by construction).
  - `bridge-1710` (`MatouBridgeMod`, E0 `SpawnCheck`/`LootCheck`
    green): `wireSpawn`/`wireLoot` seal the policy from the tables once
    (parse-once, never on the tick path) into `spawnCap`/`spawnBudget`/
    `spawnYMin`/`spawnYMax`/`lootCount` fields; the veto, the seal, the
    slots tripwire and the carrier expansion read the fields. The five
    constants are gone. Explicitly kept, documented at the constant:
    `LOOT_ORE` (ore scope rides the operator wire block — T2, not
    content), `REPOP_*` (the spike is a bridge-owned vanilla harness,
    no consumer involved), the `SPAWN=1` switch (DEV proof opt-in),
    the diamond carrier (placeholder with item-registration expiry).
  - Gates prove the flow, not the literals: `SpawnCheck`/`LootCheck`
    read the policy from `../example1/content/owned.matou` (seal +
    comparateur over wired values); store-math checks keep literals
    (they test the store, source-agnostic — same split as the
    `SpawnJob` battery).
  - Live proof (`SPAWN=1` direct client, Forge 1614, host OpenJDK
    1.8.0_502): `spawn wired <...my_beast> hp <20> cap <4> budget <1>
    y <66..68>`, `loot wired <{ore,beast}> count <1>`, census 1→4 at
    worldTicks 2..5, kill at worldTick 1000 → diamond carrier at 1001
    (elapsed 1, immediate), clean shutdown exit 0 after 4600 server
    ticks ; world == pure union (1274 cells, ids 1,165 —
    `NUMERIC_IDS=example1:my_ore=165` from the boot log, id 165 again).

  ## Operator-override tranche (live-proven 2026-09-10)

  The content-decides tranche left one question open: the author names
  the policy, but the operator runs the server. This tranche wires the
  operator answer — same seam, same budget math, no
  `SpawnJob`/`SpawnStore`/`SpawnSeal`/`LootJob`/`DropStore`/`LootSeal`
  change, no SPI change (no re-pin), no new `forge/src` file and no new
  `E_FORGE_*` (parity holds over 4 bridges, behaviour 1710-only until
  proven):

  - Vocabulary (`bridge-1710`
    `java/src/fr/iamacat/bridge/wire/OperatorPolicy.java`, pure, zero
    MC — the shared base below the `spawn`/`loot` leaves, so neither
    leaf imports the other): per wire line `spawn.cap` /
    `spawn.budget` / `spawn.y_min` / `spawn.y_max` / `loot.count`.
    Operator present wins, else content. Unknown `spawn.*`/`loot.*`
    keys refuse loudly (a typo is never a silent default); the same key
    with different values across wire lines refuses loudly (silent
    picks are defaults). Numbers validate at consumption: positive u32
    for cap/budget/count, u32 `>= 0` for the band, merged
    `0 <= y_min <= y_max` re-checked (independent overrides can invert
    a healthy content band). `hp` stays spec-only (no operator key —
    damage balance is content, a re-opener, never a quiet knob).
  - Loot scope rides no key: the ore is the packs.cfg wire-block column
    (`OperatorPolicy.wireBlocks`, ordered distinct names, the forge
    side resolves each — unresolvable refuses under the kept
    `E_LOOT_ORE` code). The `LOOT_ORE` constant is gone. Design note
    (code-read, not live-measured): wiring the dev stone default now
    pays stone harvests — content decides what each kind pays, the
    operator decides what through the wire column, as with plane cells.
    Every live proof wires the registered ore, so no proof moves.
  - `MatouBridgeMod` transports the effective policy (parse-once at
    wire time, never on the tick path): `wireLoot`/`wireSpawn` take the
    parsed specs once (the double `parseLines` is gone), the veto, the
    seals, the slots tripwire and the carrier expansion read the
    fields, `onHarvest` matches the resolved wire-block set. Default
    runs log byte-identical lines to the content-decides tranche;
    overridden runs append `overridden <keys>` (spawn) and always name
    `ore <[blocks]>` (loot).
  - Companion (`tools/autoplay`, DEV-only): `SPAWN_CAP` turns into the
    effective-cap want (`SPAWN_CAP` env wins, default 4 is the content
    cap, garbage refuses under `E_AUTOPLAY_SPAWN_CAP`). Override proofs
    set the env to the packs.cfg override — both sides name the same
    bound, or the breach check is blind.
  - Gates prove the flow, not the literals: `SpawnCheck`/`LootCheck`
    drive the shipped `OperatorPolicy` over synthetic specs (absent =
    content, full win, seal-and-decide at the overridden values,
    zero/negative/non-numeric/multi/unknown/inverted/bare-wire/null
    refusals, wire-block order + dedupe).
  - Live proof (`SPAWN=1` + `SPAWN_CAP=2` direct client, Forge 1614,
    host OpenJDK 1.8.0_502, packs.cfg = the T1 wire plus
    `spawn.cap=2`): `spawn wired <...my_beast> hp <20> cap <2> budget
    <1> y <66..68> overridden <cap>`, `loot wired <{ore,beast}> count
    <1> ore <[example1:my_ore]>`, census 1→2 at worldTicks 2..3 (same
    RNG pads as the T1 run, which landed 0..3 — landings stop at ticks
    0,1 here, the decisive precedence signal), kill at worldTick 1000
    → diamond carrier at 1001 (elapsed 1, immediate), clean shutdown
    exit 0 after 4600 server ticks ; world == pure union (1274 cells,
    ids 1,165, `NUMERIC_IDS=example1:my_ore=165` from the boot log, id
    165 again). Zero `E_*` refusals. Coverage split, stated: live
    proves the cap override plus the wire-block ore scope ;
   count/y overrides ride the same validator family and are proven at
   E0 ; the 48-veto path is T1-proven on the same hook, not re-run
   (no natural joins this seed).

## 1122 port tranche (live-proven 2026-09-10)

T1 vanilla scope on Forge 2860 (bridge-1122 `c53cc23` E0 + `c030d4b`
live): the full 1710 behavior minus the custom entity — census, seal,
content-decided hp/cap/budget/band, operator overrides, T3 vocabulary —
landing vanilla pigs (zero registration risk, same species as the loot
victim until registration lands). `SpawnStore`/`SpawnSeal`/`SpawnCheck`
are byte-identical copies ; `MatouEntity` stays a shell (the
`PORT_QUEUE` custom-entity row does not move) ; the companion counts /
hp-polls / kills pigs (no `required-after` — pig frame refs are
vanilla, always sourced).

- 2860 shapes (measured via javap + joined.tsrg against the pinned
  bytes, live-proven) : join entity/world behind
  `getEntity()`/`getWorld()` (the 1.7.10 public-field shape does not
  port — field reads would die linking, same lesson as the loot
  `BlockEvent`) ; the join event is `@Cancelable` (the veto cancels
  through it) ; hp through `getEntityAttribute` / `setBaseValue` /
  `setHealth` / `getMaxHealth` (same stable SRG names as 1710) ;
  narrow map 21→30 rows ; `E_SPAWN` joins the run-live refusal grep.
- Two red runs, both loud by design. First: the E0 run staged against
  the stale 21-line map (the map re-derives at run-live start, staging
  reuses it) and died `NoSuchFieldError: loadedEntityList` on the
  first reconcile — the fix is discipline, not code: re-run etage 3
  (re-derive + re-proof) before staging after any WANT change. Second:
  the census id was anchored `func_82145_z` from memory — notch `Z()`
  returns constant 1 (measured via `javap -c`), so every landing
  recorded under one id, the veto went blind, and the companion
  breached `<5 > 4>` at worldTick 6. The id getter is the method
  returning the ctor-counter field `equals`/`hashCode` use (measured
  via `javap -c`: obf `S`), i.e. `func_145782_y`. Rule for the next
  ports: the derive pins SRG↔notch, but nothing pins the MCP name↔SRG
  link except the stable CSV cross-check plus live behavior — an
  anchor sourced from memory is a guess until the census holds live.
- Dots-normalize derive fix (bridge-1122 `run-live.sh`, one line,
  same replace as hub `tools/run-client.sh`): unobfuscated
  `java.util.List` keeps its dots in javap while SRG descriptors use
  slashes, so the anchored-field check failed for
  `World/loadedEntityList` — the hub autoplay derive already carried
  the replace (the loot companion pins the same field), the live
  derive did not.
- Live proof (`SPAWN=1` direct client, Forge 2860, host OpenJDK
  1.8.0_502, ore-wire legacy pack): `spawn wired
  <example1.content:my_beast> hp <20> cap <4> budget <1> y <66..68>`,
  4 landings at ticks 0..3 (census 4 at worldTick 5, cap), `spawn hp
  <20.0>` at worldTick 2, a silent natural join adopted at tick 49
  (the 1710 event-bypass lesson re-measured on 2860) plus its death
  paid through the loot table the same tick, sweep + replacement at
  69, 1 past-cap veto at tick 400, companion kill at worldTick 1000 →
  bridge tick 999, diamond carrier the same tick, polled at 1001
  (elapsed 1, immediate), replacement landed at 999, clean shutdown
  exit 0 after 4600 server ticks ; world == pure union (1274 cells,
  ids 1,253 — `NUMERIC_IDS=example1:my_ore=253` passed to the
  verifier, same id as every 2860 proof). Zero `E_*` refusals. Same
   round : server path re-proven on the fixed bytes (150s 2860 run,
   world == pure union 1922 cells, vein wire, spawn passive).
   `PORT_QUEUE` spawn row live on 1122 (second runtime).

- Custom entity live addendum, same bridge (bridge-1122 `a3cab40` E0
  bytes, zero fix — green first try) : the T1 pig retires, landings use
  `new MatouEntity(world)` on the registered `example1:my_beast`. Both
  1165 lessons are N/A here by construction, not by luck : the beast
  registers under the full SPI mob ref verbatim (`new
  ResourceLocation(mob)` — no modid shortening, so no registry-id
  tripwire skew) and the setup tripwire stays class-keyed
  (`lookupModSpawn(MatouEntity.class, true)`, the 1.7.10 shape) ; fresh
  types need no attribute event on the old `EntityRegistry` path (pig
  attributes inherit through `EntityPig` — the spawn seam already lands
  vanilla pigs through the same ctor, live-proven). E0 added universal
  pins only (5 Forge-presence pins, never a narrow row), so no
  stale-map class either — narrow map unchanged at 30 lines.
- Custom entity live proof (`SPAWN=1` direct client, Forge 2860,
  host OpenJDK 1.8.0_502, ore-wire legacy pack) : `spawn wired
  <example1.content:my_beast> hp <20> cap <4> budget <1> y <66..68>`,
  `registered-entity <example1.content:my_beast>`, 4 landings at ticks
  0..3 (census 4 at worldTick 5, cap), `spawn hp <20.0>` at worldTick
  2, silent natural join adopted at tick 49 (`<3,4,0>`, fallen
  off-plane) with its death paid through loot the same tick, sweep +
  replacement landed at 69, companion kill at worldTick 1000 → bridge
  tick 999, diamond carrier the same tick, polled at 1001 (elapsed 1,
  immediate), replacement landed at 999, clean shutdown exit 0 ;
  world == pure union (1274 cells over 4000 ticks, ids 1,253 —
  `NUMERIC_IDS=example1:my_ore=253` from the boot log, id 253 same as
  every 2860 proof). Zero `E_*` refusals. The client tracked the
  registered beast on the vanilla `RenderPig` mapping with no renderer
  complaint (the `IRenderFactory` single-`(RenderManager)`-ctor path
  measured green, not assumed). Same round : server path re-proven on
  the same bytes (C3 run, world == pure union 1922 cells, vein wire,
  spawn passive). `PORT_QUEUE` custom entity row live on 1122 (third
  runtime).

## 1165 port tranche (live-proven 2026-09-10)

T1 vanilla scope on Forge 36.2.42 (bridge-1165 `a848669` E0 +
`c2bad06` live): the full 1710 behavior minus the custom entity —
census, seal, content-decided hp/cap/budget/band, operator overrides,
T3 vocabulary — landing vanilla pigs (zero registration risk, same
species as the loot victim until registration lands).
`SpawnStore`/`SpawnSeal`/`SpawnCheck` are byte-identical copies ;
`MatouEntity` stays a shell (the `PORT_QUEUE` custom-entity row does
not move) ; the companion counts / hp-polls / kills pigs.

- 36.2.42 shapes (measured via javap + joined.tsrg + snapshot
  20210309 against the pinned bytes, live-proven) : the census poll
  is `World.getEntitiesWithinAABB` (no `loadedEntityList` field ships
  on 1.16.5, tranche-1 +-512 window) ; the living check is the
  `removed` field ; the id is `getEntityId` (`func_145782_y`, never
  the 1122 memory-anchored `func_82145_z`) ; landings position
  through `setPositionAndRotation` ; the sink is
  `ServerWorld.addEntity` ; the victim is
  `new PigEntity(EntityType.PIG, world)` ; the hp lands through
  `LivingEntity.getAttribute` on `Attributes.MAX_HEALTH` ; the
  simulated kill removes through `remove()` ; the veto cancels a
  `@Cancelable` `EntityJoinWorldEvent`. Narrow map 19→29 rows ;
  `E_SPAWN` joins the run-live refusal grep ; autoplay derive
  3→16 rows.
- Three red runs, all loud by design. First (hub tooling) : the
  Forge-first classpath dedup (log4j fix) shadowed the vanilla
  duplicate lwjgl entries (plain + natives-classifier rows share one
  group:artifact) and starved the natives dir — the game died
  `UnsatisfiedLinkError: liblwjgl.so` before boot. Fixed in hub
  `tools/run-client-direct.sh` : a deduped lib still donates its
  `natives-linux` classifier (main jar stays Forge-first, natives
  additive). Second (bridge) : the `ItemStack` ctor was stubbed
  `(Item,int)` from javap alone, but the runtime shape is
  `(IItemProvider,int)` (obf `brw` maps to the interface per
  joined.tsrg, `blx`/`Item` implements it) — `NoSuchMethodError` at
  the first carrier drop. Fixed by an `IItemProvider` stub plus
  `Item implements` (the E0 comment claimed the wrong shape measured
  — a stub comment is a guess until the carrier drops live). Third
  (companion) : the kill/poll legs read `getPosX/Y/Z` with no WANT
  rows (Reobf left the MCP names) — `NoSuchMethodError` at the
  worldTick-1000 kill. Fixed by 3 SRG-anchored M rows
  (`func_226277_ct_/226278_cu_/226281_cx_`, snapshot + tsrg + javap
  triple-locked — `()D` is shared by nine Entity members, the anchor
  picks the intended three). Standing rule, fourth measurement : the
  dedicated-server gate never fires the harvest/kill paths, so only
  the client proof covers them (the 150s server re-proof stayed
  green through all three reds, blind).
- Live proof (`SPAWN=1` direct client, Forge 36.2.42, host OpenJDK
  1.8.0_502, ore-wire legacy pack) : `spawn wired
  <example1.content:my_beast> hp <20> cap <4> budget <1> y <66..68>`,
  4 landings at ticks 0..3 (census 4 at worldTick 4, cap), `spawn hp
  <20.0>` at worldTick 1, natural adopted at tick 49 with its death
  paid through the loot table the same tick, sweep + replacement at
  69, companion kill at worldTick 1000 → bridge tick 1000, diamond
  carrier the same tick, polled at 1001 (elapsed 1, immediate),
  replacement landed at 1000, clean shutdown exit 0 after 4600
  server ticks ; world == pure union (1274 cells, stone names — no
  numeric ids on 1.16.5). Zero `E_*` refusals, zero past-cap vetos
  this seed (the veto path stays T1/1122-proven). Same round :
  server path re-proven on the fixed bytes (150s 36.2.42 run, world
   == pure union 1922 cells, vein wire, spawn passive).
   `PORT_QUEUE` spawn row live on 1165 (third runtime).

- Custom entity live addendum, same bridge (bridge-1165 `0b86c2d` E0
  + `f6e98e5`/`a86e3a7` live fixes) : the T1 pig retires, landings use
  `new MatouEntity(Example1Mod.beastType(), world)` on the registered
  `example1:my_beast`. Three red runs, all loud by design. First
  (bridge) : the setup tripwire looked up the SPI mob ref
  (`example1.content:my_beast`) while the `DeferredRegister` builds the
  entry id from its own modid (`example1:my_beast`) — the 1.7.10
  tripwire is class-keyed (`lookupModSpawn`) and never reads the
  string, so the verbatim copy only worked there. Fixed by
  `registeredEntity = MODID + ":" + shortName`. Second (bridge) : the
  first landing NPEd inside the vanilla `LivingEntity` ctor — fresh
  types carry no attribute map. Fixed by a mod-bus
  `EntityAttributeCreationEvent` listener reusing the vanilla pig map
  wholesale (`PigEntity.func_234215_eI_().create()`, pig-identical,
  never hand-copied values ; the builder ships with no MCP name in
  snapshot 20210309 so it stays SRG-direct, passthrough, while the
  finishing `create` rides the narrow map 33→34, triple-locked).
  Third (pipeline, not code) : the new call died un-reobfed — the
  direct-client staging never re-derives, it reuses the live
  `srg-narrow.srg` (stale 33 lines). Fixed by the 150s server re-proof
  on the fixed bytes (world == pure union 1922 cells, map regenerated
  to 34), then re-stage + re-run. Standing rule : a narrow-map row
  added E0-side is dead until a live-side derive regenerates the
  shared map — the server proof is that derive.
- Custom entity live proof (`SPAWN=1` direct client, Forge 36.2.42,
  host OpenJDK 1.8.0_502, ore-wire legacy pack) : `registered-entity
  <example1:my_beast>`, 4 landings at ticks 0..3 (census 4 at
  worldTick 4, cap), `spawn hp <20.0>` at worldTick 1, natural adopted
  with death paid through loot at tick 49, sweep + replacement at 69,
  companion kill at worldTick 1000 → diamond carrier the same tick,
  polled at 1001 (elapsed 1, immediate), replacement landed at 1000,
  clean shutdown exit 0 ; world == pure union (1274 cells over 4000
  ticks, ore + stone names — no numeric ids on 1.16.5). Zero `E_*`
  refusals. The client tracked the registered beast on the vanilla
  `PigRenderer` mapping with no renderer complaint (client link
  measured green, not assumed). `PORT_QUEUE` custom entity row live
  on 1165 (second runtime).

## 1201 port tranche (live-proven 2026-09-10)

T1 vanilla scope on Forge 47.2.0 (bridge-1201 `7c68916` E0, zero fix
— green first try) : same behavior as above, landing vanilla pigs.
The E0 spelling held end to end : the join is
`EntityJoinLevelEvent` (`@Cancelable`, entity on the `EntityEvent`
base, level on the subclass) ; the census poll is
`EntityGetter.getEntitiesOfClass` ; the id is `Entity.getId` ; the
living check `Entity.isAlive` ; landings position through
`Entity.moveTo` ; the sink is `ServerLevel.addFreshEntity` ; the
victim is `new Pig(EntityType.PIG, level)` ; the hp lands through
`LivingEntity.getAttribute` on `Attributes.MAX_HEALTH`. Narrow map
17→27 rows ; the companion coords (`getX/Y/Z`), `discard` and the
carrier poll rode rows the loot tranche already pinned — the 1165
missing-WANT class does not repeat.

- Live proof (`SPAWN=1` direct client, Forge 47.2.0, host Temurin
  17.0.20, ore-wire legacy pack) : `spawn wired
  <example1.content:my_beast> hp <20> cap <4> budget <1> y <66..68>`
  (`loot wired <{ore,beast}> count <1> ore <[example1:my_ore]>` —
  the registered ore by name), 4 landings at ticks 0..3 (census 4 at
  worldTick 5, cap), `spawn hp <20.0>` at worldTick 2, fallen pig
  paid through the loot table at tick 73 (y=-60, off-plane fall like
  the 1614 proof) with replacement landed the same tick, companion
  kill at worldTick 1000 → bridge tick 999, diamond carrier the same
  tick, polled at 1001 (elapsed 1, immediate), replacement landed at
  999, clean shutdown exit 0 after 4600 server ticks ; world == pure
  union (1274 cells, ore + stone names — no numeric ids on 1.20.1).
  Zero `E_*` refusals, zero past-cap vetos this seed. No bridge code
  change (E0 bytes), so no server re-proof (bytes-identical
  precedent — the E0 tranche already re-proved 1922 cells).
   `PORT_QUEUE` spawn row live on 1201 (fourth runtime) ; vocabulary
   row live on 1201 (loot live + spawn live, same rationale as the
   1122 flip).

- Custom entity live addendum, same bridge (bridge-1201 `4ede749` E0 +
  `bfe18f1` live fix) : the T1 pig retires, landings use
  `new MatouEntity(Example1Mod.beastType(), level)` on the registered
  `example1:my_beast`. One red run, loud by design. The E0 guessed the
  renderer shape right (dist-filtered nested `@Mod.EventBusSubscriber`
  — the 1.16.5 `RenderingRegistry` call does not exist on 1.20.1) but
  missed what no earlier bridge could teach : an `invokedynamic` names
  its SAM in the compiled namespace, and both vanilla SAMs the beast
  touches are SRG-renamed at runtime
  (`EntityRendererProvider.create` → `m_174009_`,
  `EntityType$EntityFactory.create` → `m_20721_`, measured via the
  pinned SRG client/server jars). The first client run died
  `AbstractMethodError` at the renderer registration (the factory
  would have died the same way at the first landing — same mechanism,
  unreached). Fixed in the shared tooling, not the sources :
  `tools/live/Reobf.java` rewrites indy names off the same narrow-map
  MD lines (owner ignored — an indy carries none — with an ambiguity
  refusal), fed by two new SAM rows (the factory through the server
  chain, the provider through the pinned client.txt — client classes
  never ship server-side, no javap leg there by construction, the
  exact-one asserts on both hops plus this run lock the row ; narrow
  map 27→35). The 1165/1122 SAMs need nothing (runtime-stable there by
  construction : a Forge SAM on 1165, `java.util` factories on 1122).
  Standing rule : any lambda/method-ref targeting a vanilla SAM ships
  the SRG indy name or dies at link time — method calls were never
  affected (only indys name their target in the compiled namespace).
- Both 1165 lessons held by construction here, verified live rather
  than re-hit : the setup tripwire looks up the registry id
  (`example1:my_beast` from this `DeferredRegister`'s own modid, never
  the SPI mob ref `example1.content:my_beast`) and the beast's
  attribute map registers on the mod-bus
  `EntityAttributeCreationEvent` (vanilla pig map reused wholesale as
  `Pig.createAttributes().build()` — pig-identical values measured on
  the pinned 47.2.0 bytes : `CREATURE` / `0.9 x 0.9` / tracking 10 via
  `javap -c` on the SRG game jar, update interval default). Vanilla
  PIG values mirrored, never recalled.
- Custom entity live proof (`SPAWN=1` direct client, Forge 47.2.0,
  host Temurin 17.0.20, ore-wire legacy pack) : `spawn wired
  <example1.content:my_beast> hp <20> cap <4> budget <1> y <66..68>`,
  `registered-entity <example1:my_beast>`, 4 landings at ticks 0..3
  (census 1→4 at worldTicks 1..4, cap), `spawn hp <20.0>` at worldTick
  1, fallen beast paid through loot at tick 73 with replacement landed
  the same tick (off-plane fall, same-tick pattern as the T1 1201
  proof), companion kill at worldTick 1000 → bridge tick 1000,
  diamond carrier the same tick, polled at 1001 (elapsed 1,
  immediate), replacement landed at 1000, clean shutdown exit 0 after
  4600 server ticks ; world == pure union (1274 cells over 4000 ticks,
  ore + stone names — no numeric ids on 1.20.1). Zero `E_*` refusals.
  The client tracked the registered beast on the vanilla `PigRenderer`
  mapping with no renderer complaint (the nested-subscriber +
  `RegisterRenderers` path measured green, not assumed). Same round :
  server path re-proven on the fixed bytes (150s 47.2.0 run, world ==
  pure union 1922 cells, vein wire, spawn passive — the run that
  regenerated the shared 35-line map).
  `PORT_QUEUE` custom entity row live on 1201 (fourth runtime).

- `SideOnly` stub-retention addendum (1710, found live on T4 bytes) :
  the first dedicated-server run after the custom entity tranche died
  at mod load (`NoClassDefFoundError: ModelPig`) while every direct
  client run stayed green — the client classes exist there, so nothing
  could catch it. The `SideOnly` compile stub lacked
  `@Retention(RUNTIME)`, javac filed the annotation invisible
  (`RuntimeInvisibleAnnotations` on `registerBeastRenderer`, measured
  by `javap -v`), and Forge 1.7.10 strips visible annotations only —
  the renderer mapping survived on the server. Same bug class as the
  1201 invisible-`@SubscribeEvent` lesson (stub annotations mirror
  `RUNTIME` retention), this time loud instead of silent. Fixed in the
  shared tooling, not the sources : retention (+`TARGET`
  TYPE/FIELD/METHOD/CONSTRUCTOR) mirroring the pinned universal bytes,
  and `run-live.sh` locks the visibility on the exact compiled bytes
  (`javap -v` block check, never the pool ref). Standing rule : every
  side-stripped annotation stub carries the runtime's retention, and
  the live pipeline asserts it on the shipped bytes — E0 compiles
  against stubs and cannot see visibility. Open re-opener : 1122
  carries the same retention-less stub shape while server-green there
  (measured stub bytes, unexplained — likely the `invokedynamic`
  renderer factory defers resolution where 1710's `new` does not) ;
  the T4 port tranche re-runs the 1122 server proof and either
  reproduces or retires this question, never inherits it silently.
  RETIRED 2026-09-11 by the T4 1122 port (bridge-1122 E0 `326dc1d`) :
  the stub now mirrors the pinned 2860 bytes (RUNTIME +
  TYPE/FIELD/METHOD/CONSTRUCTOR, javap-measured on the provisioned
  Forge server jar — same retention as the 1710 universal) with the
  same `javap -v` block lock in `run-live.sh`, and the server re-proof
  on the fixed bytes stays green (150s 2860 run, world == pure union
  1922 cells, ids 1,253). The pre-fix greenness cause is unreproduced
  and needs no reproduction : the standing rule holds the retention,
  the lock holds the bytes.

## Addendum — per-mob spawn seals, second-beast E0 (2026-09-11)

`SpawnTable` seals per-mob hp/cap/budget/y maps (spi `3eb6e8d`,
example1 `41c8fa1`, hub `decisions/VIRTUAL_HITBOXES.md` second-beast
row): the `:multi` table refusal is retired (multi is now legal),
sole-mob views refuse multi mirroring `CombatTable`, and `SpawnJob`
decides per mob over a mixed census (room/due per mob,
mob-addressed RNG pads, foreign = outside the sealed TABLE list).
`SpawnStates.TABLE` accepts the ordered qualified-ref list (the sole
string stays valid — single-mob seals decide identical cells, proven
by golden). Operator overrides apply uniformly per mob until
per-mob keys land (named follow-up, never a quiet per-mob knob).
Lead `wireSpawn`/`SpawnSeal`/census dispatch per mob
(bridge-1122 `991e004`, entity mob persisted via NBT); siblings keep
single-mob seals with per-mob content oracles
(1710 `aabc70c`, 1165 `16dcfcc`, 1201 `8bdf576` — dispatch ports
TODO). Live proof TODO (second entity registration first).

## Addendum — qualified PolicyPack mob view, E0 all bridges (2026-09-11)

Closes the last named follow-up of the per-mob rows (hub
`decisions/LOOT.md` staying-open line, `VIRTUAL_HITBOXES.md`
second-beast registration row): the spawn wire no longer reads the
file namespace off the loot drop refs.

- `spi` `f1499ee` (additive): `PolicyPack.spawnMobRef(String mob)`
  serves one sealed mob's qualified `ns:name` ref — never null/empty,
  loud on null/unknown mob, never defaulted. Per-mob shape like every
  other per-mob view (no order coupling between `spawnMobs()` and the
  qualification). No existing view touched, no reseal.
- `example1` `63ff7b7`: `SpawnTable.mobRef(String mob)` (same
  `E_EXAMPLE_SPAWN` null/unknown shape as the other per-mob readers)
  plus `ExamplePolicy.spawnMobRef` / `ExamplePack.spawnMobRef`
  delegates (twenty-eight `PolicyPack` accessors now) ;
  `ExampleCheck` battery — owned/single/tmp per-mob values,
  null/unknown refusals, pack-level values + unknown refusal,
  unwired probe (535 oks).
- Bridges (byte-identical hunk each, zero MC delta, zero narrow-map
  delta): `wireSpawn` qualifies through
  `policy.spawnMobRef(shortMob)` (1710 `5dc3a2a`, 1122 `3338075`,
  1165 `417b5f5`, 1201 `de4f525`), `contentNamespace()` deleted —
  the `E_SPAWN_MOB:nowire` / `:null drop` tripwires retire with it
  (the `E_SPAWN_MOB` family stays thrown elsewhere, so the parity
  catalog is unchanged) ; SPI pins bumped to `f1499ee` on all four.
- Zero behaviour difference, proven not asserted: the battery pins
  `spawnMobRef(m)` against the old `ns + ":" + m` derivation on the
  shipped two-mob content (`example1.content:my_beast`,
  `example1.content:my_brute`) — the same maps land under the same
  keys. Stages 1-2 green everywhere (spi checks, example1 535 oks,
  4 bridge gates incl. forge + autoplay compile).
- Lead live (bridge-1122 `3338075`, zero live fixes — host OpenJDK
  1.8.0_502): 150 s Forge 2860 server green (world == pure union
  1922 cells, ids 1,253, per-mob spawn wire lines, zero `E_*`) ;
  headless direct-client `SPAWN=1 COMBAT=1` (exit 0) — census 2→8
  balanced at worldTicks 2..5, hp 20.0 + 30.0, beast head x2 → 18.0
  at 501 then brute head x3 → 27.0 at 601 (elapsed 1 each), spawn
  kill pins `<13,66,9:my_beast>` at 1000 → carrier tick 999 → gem
  polled at 1001 (elapsed 1), replacement joined the same tick under
  the qualified ref `example1.content:my_beast` (the new view's
  string end to end), clean shutdown at 4600 ticks, save pure union
  1274 (id 253 via `NUMERIC_IDS`, pre-flattening era), zero `E_*` /
  linkage (benign gem-model `Caused by` only, same as every 1122
  proof). Sibling live 1710 done (same legs, byte-identical hunk,
  zero live fixes — bridge stays `5dc3a2a`, SPI pin `f1499ee`
  untouched, host OpenJDK 1.8.0_502 on the server side): `B3_OFFLINE=1
  sh tools/run-live.sh` exit 0 first try (150 s Forge 1614 run, world
  == pure union 1922 cells ids 1,165 with `my_ore` id 165 dynamic off
  the boot log, per-mob spawn wire `{my_beast hp <20> cap <4> budget
  <1> y <66..68>},{my_brute hp <30> cap <4> budget <1> y <66..68>}` plus
  `registered-entity <example1.content:my_beast,
  example1.content:my_brute>`, zero `E_*` — sole `Caused by` is Forge's
  own offline version check, benign) ; headless direct-client
  `NUMERIC_IDS=example1:my_ore=165 SPAWN=1 COMBAT=1` exit 0 end to end
  (internal `ok verify-client : world == pure union (1274 cells, 1,165
  only)`) — census 2→8 balanced at worldTicks 2..5, hp 20.0 + 30.0 at
  tick 2, beast head x2 → 18.0 at 501 then brute head x3 with drop=3.0
  exact at 601 (elapsed 1 each), spawn kill at 1000 → gem at 1001
  (elapsed 1), replacement joined the same tick 999 under the qualified
  ref `example1.content:my_beast`, clean shutdown at 4600 ticks, zero
  `E_*` / linkage. Trouvailles: the struck-brute baseline reads
  ambient-damaged (18.0 then 19.0 across two runs — deterministic brute
  churn `loot recorded <…:beast.my_brute>` at ticks 308/324 with adopted
  replacements, same class as the 1201 ambient-falls note ; the drop
  stays exact either way, so the weakspot proof holds) ; the internal
  verdict inherits `NUMERIC_IDS` from env, so the era-native id rides
  the direct-client invocation itself (omitting it leaves the game legs
  green and fails only the replay — same shape as every 1710 proof).
  1165+1201 sibling live TODO.
