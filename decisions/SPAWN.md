---
type: spec
status: active
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
