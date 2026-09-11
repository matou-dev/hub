---
type: spec
status: active
maturity: standard
scope: shared
roadmap: -
---

# Loot — event-sourced drops on the repop seam

Date: 2026-09-10
Status: active (first consumer: example1 `LootJob`/`LootTable` + bridge-1710 live wire, live-proven 2026-09-10)

## Problem

`item my_gem` and `mob my_beast` (`drop = example1.content:my_gem`)
are declared in `example1/content/owned.matou` and consumed nowhere:
no job in `example1` reads `drop`, no kernel in `spi` knows loot, no
hook in any bridge touches drops (the only `SpawnX/Y/Z` hit
repo-wide is the autoplay `preseed.py` level.dat preseed — world
spawn point, not loot). The loot table is unwired: mining the future
custom ore drops nothing, killing the future beast drops nothing.

## Decision

Event-sourcing, repop-seam shape (`decisions/REPOP_SPIKE.md`: store ->
seal -> pure decide -> land, tripwire on live divergence):

- `DropStore` (bridge-owned, plain data, zero MC — `MinedStore`
  shape): `record(drop, tick)` on harvest events, `claimDue`,
  `sealed()` copy.
- Forge hooks (bridge `forge` package only, Q2 holds):
  `BlockEvent.HarvestDropsEvent` for blocks (including the registered
  ore) plus `LivingDropsEvent` for mobs, server side, dim-0 first
  (same dim filter lesson as the spike). Client echoes ignored; other
  dims out of scope, not errors.
- `LootSeal` (pure) seals the store beside `pack.states` through the
  `ForgeSnapshot.snapshot` choke point — SPI untouched (same
  decoration answer as the spike: no `decideAll` change, no re-pin).
- `LootJob` (pure, `MatouJob` contract): reads the loot-table states
  (drop refs + chances/counts from the snapshot) plus the sealed
  harvest set, emits `EntityItem` decisions. Missing/wrong-typed
  states refuse loudly (`E_LOOT_*`), never defaulted.
- Landing: the bridge converts due drops to `EntityItem` spawns
  through a version-native sink (same sink family as
  `WorldCellSink`). A live `claimed != due` divergence fails the tick
  loudly (`E_LOOT_SEAL:diverged`, spike-tripwire shape).

Data constraint: V1's closed 4 genres stay frozen — loot rides the
existing `item`/`mob.drop` refs plus the `vein` block (fields land in
the V4-delta family, never a fifth genre smuggled in with the job).
Codes `E_LOOT_*` stay tranche-local in the existing
`MatouBridgeMod.java` (spike precedent), so `check-bridges.sh`
parity holds with behaviour 1710-only until proven. Thrown set
(PORT_QUEUE-declared, `decisions/BRIDGE_PARITY.md`): `E_LOOT_GEM`
(unknown carrier), `E_LOOT_ORE` (scope), `E_LOOT_SEAL:diverged`
(tripwire), `E_LOOT_SPAWN` (refused spawn), `E_LOOT_TABLE:multi`
(single-table scope), `E_LOOT_STORE` (`DropStore` args/range),
`E_LOOT_WIRE` (operator count/ore transport).

Explicit non-goals for tranche 1: fortune/silk-touch modifiers,
conditional tables (biome, moon phase), experience orbs.

## Landed shape (tranche 1, live-proven 2026-09-10)

- `example1` (`LootJob` + `LootTable`, E0 `ExampleCheck` green):
  `LootJob` is stateless like `OwnedVeinJob` and reads
  `example1.loot:harvested` (map) + `:table` (kind to content item
  ref) + `:count` (Counts-style trio under `E_LOOT_COUNT`) from the
  snapshot, emitting volume drop cells with the content item ref.
  `LootTable.fromFile(owned)` seals `{ore, beast}` to the single mob
  drop — zero or several mobs refuse loudly (single-table scope).
  `ExamplePack` untouched (no new job branch, no new states).
- `bridge-1710` (`fr.iamacat.bridge.loot`, E0 `LootCheck` green):
  `DropStore` (record/claimDue/sealed, immediate — due at harvest
  tick) + `LootSeal.seal(store, table, count)` beside the first wire's
  pack states (SPI untouched, no re-pin) + comparateur (claim expanded
  by the table equals the decision, counts 1..2).
- Forge wire (`MatouBridgeMod`, `E_LOOT_*` local, parity holds):
  `LOOT_ORE` scope constant + `LOOT_COUNT=1` policy constant (spike
  `REPOP_DELAY` shape), `wireLoot` from the packs' `ownedFile`
  (passive without, multi refuses), `lootTick` with the
  `E_LOOT_SEAL:diverged` tripwire on the expanded claim, diamond
  carrier sink beside vanilla drops.
- Live proof (`LOOT=1` direct client, Forge 1614, host OpenJDK
  1.8.0_502): companion harvests the registered ore at (8,10,8) at
  worldTick 1000 and kills a spawned pig at (12,10,8) at 1005 —
  recorded bridge ticks 999/1004, one diamond carrier dropped the same
  tick each, both polled within 1 tick (immediate, no repop delay).
  Clean shutdown exit 0 after 4600 server ticks, world == pure union
  (1274 cells, ids 1,165 — ore-wire legacy pack, drops are entities).
  Client packs.cfg for the proof wires `example1:my_ore` with no vein
  file; the union verdict takes `NUMERIC_IDS=example1:my_ore=165`
  (dynamic id from the game log, per-name-IDs model).

## Measured findings

- 1122 port shapes (measured via javap against the pinned 2860 bytes,
  live-proven 2026-09-10, bridge-1122 `5f09424`): `BlockEvent`
  world/pos/state hide behind `getWorld()/getPos()/getState()` (the
  1.7.10 public-field shape does not port — field reads die linking);
  `LivingDropsEvent` ctor is 5-arg (no `specialDropValue`);
  `EntityItem.getItem` returns `ItemStack` (not `Item`); `posY/posZ`
  are `field_70163_u`/`field_70161_v` (not the `70165` sequence);
  `setBlockToAir` is `func_175698_g`, `isAirBlock` is `func_175623_d`
  (the `(BlockPos;)Z` overload family is wide — MCP names
  cross-checked against `mcp_stable-39`); the autoplay derive (hub
  `tools/run-client.sh`) handles `F` rows on the MCP path since this
  tranche (first field-needing companion). T1 victim is a vanilla pig
  until custom-entity registration lands.

- 1201 port shapes (measured via server.txt + joined.tsrg v2 + javap
  against the pinned 47.2.0 bytes, live-proven 2026-09-10, bridge-1201
  `58b9707`): the harvest post is a `level`-package `BreakEvent`
  (the 1.12 `HarvestDropsEvent` shape is gone — breaks arrive through
  it on the forge side too); clears go through `removeBlock` (the 1.12
  `setBlockToAir` shape does not port); air probes go through
  `BlockStateBase.isAir`; the victim is a `new Pig(type, level)` (the
  1.12 no-arg shape does not port — the type resolves through
  `ForgeRegistries.ENTITY_TYPES`); positioning goes through
  `Entity.setPos` and removal through `Entity.discard` (the 1.12
  `setPositionAndRotation`/`setDead` shapes do not port); carriers poll
  through `EntityGetter.getEntitiesOfClass` over one `AABB` per spot
  (the 1.12 `loadedEntityList` field shape does not port); the diamond
  resolves through `ForgeRegistries.ITEMS` (the Mojmap autoplay derive
  pins methods only — no vanilla field touched); the dim gate compares
  `dimension().location()` to `"minecraft:overworld"` (no `OVERWORLD`
  field); the echo gate is `isClientSide()` (no `LogicalSide` surface
   in the companion at all). `IEventBus.post` lives in the eventbus lib,
   not the universal: unstaged pin, proven live. T1 victim is a vanilla
   pig until custom-entity registration lands.
- 1165 port shapes (measured via joined.tsrg + snapshot 20210309 + javap
  against the pinned 36.2.42 bytes, live-proven 2026-09-10, bridge-1165
  `42d48c4`): the ore resolves through `ForgeRegistries.BLOCKS`
  (presence first — `getValue` returns air for unknown names, never
  null, same as the bridge wire); the state comes from
  `Block.getDefaultState`; air probes go through `World.getBlockState`
  + `BlockStateBase.isAir`; place goes through `World.setBlockState`,
  clear through `World.removeBlock` (the 1.12 `setBlockToAir` shape
  does not port); the player comes from `ServerWorld.getPlayers` (no
  `playerEntities` field ships on 1.16.5); the victim is a
  `new PigEntity(EntityType.PIG, world)` (the 1.12 no-arg shape does not
  port); the spawn lands through `ServerWorld.addEntity` (the loot
  sink); carriers poll through `World.getEntitiesWithinAABB` over one
  box per spot. T1 victim is a vanilla pig until custom-entity
  registration lands.
- Wire-driven registration (first 1165 live run failed loud pre-place,
  never silent): `Example1Mod` only queues blocks named in the
  packs.cfg wire column, so the stone-wire default registers nothing
  and the companion resolve refuses (`unknown <example1:my_ore>`) —
  the loot proof wires `example1:my_ore` with no vein file (the 1710
  ore-wire pack shape), the union plane lands as the registered ore.
- Owner-discipline re-measurement (second 1165 live run crashed loud
  at the first harvest, the derive green): the companion read `isAir`
  through `BlockState` while the member lives on the declaring
  `AbstractBlockState` (`NoSuchMethodError: BlockState.isAir`, never
  silent) — fixed by an upcast local (same as the 1201 `Level` fix,
  fourth measurement of the standing rule).
- Companion-WANT discipline (same run, ore leg green first): the beast
  leg positioned through `setPositionAndRotation` with no companion
  WANT row (Reobf left the MCP name — `NoSuchMethodError` in the
  server tick loop, second 1165 missing-WANT miss after the spawn
  `getPosX` trio). Fixed by one SRG-anchored M row.
- Owner-discipline re-measurement (first 1201 live run failed loud at
  the first harvest post, the derive green): `onHarvest` read
  `isClientSide`/`dimension` through the narrowed `ServerLevel`
  (`NoSuchMethodError: ServerLevel.isClientSide` — Reobf maps the exact
  bytecode owner, the `Level`-keyed narrow map never sees a subclass
  call site). Fixed by a `Level` upcast (same as `onKill`, same as the
  1710 `worldObj` lesson). Standing rule, third measurement: inherited
  vanilla members go through the declaring stub type at every call
  site, forge and companion alike — and the dedicated-server gate never
  fires harvest/kill events, so only the client proof covers the hooks
  (the 150s server re-proof on the fixed bytes stayed green throughout,
  blind to the bug).

- Stub-owner discipline: reobf only walks in-jar superclass chains and
  stub supertypes never ship, so `EntityItem.posX`,
  `EntityLivingBase.worldObj` and pig calls kept their MCP names into
  the first live run and died linking (`NoSuchFieldError: posX` in the
  carrier poll — loud crash, rc=255, never a silent pass). Inherited
  vanilla members are read through the declaring stub type
  (`Entity`), in forge and companion alike — the crash class the
  `no-stub-const` gate cannot see.
- Drops are immediate (elapsed 1 tick harvest to carrier both legs):
  the delay knob stays repop's alone.
- The diamond carrier, the any-kill-pays scope and the kind vocabulary
  (`ore`/`beast`) expire with their documented successors (item
  registration, per-mob tables — the custom-entity successor is spent:
  the loot legs kill the registered beast since the hub
  decisions/SPAWN.md custom entity tranche; see re-openers below).

## Gates (will prove the tranche)

- E0 pure green: `DropStore` semantics, seal isolation, job boundary,
  refusals, store-vs-job comparateur, etage 1.
- Live-build replica green: new event pins resolved
  (`HarvestDropsEvent`, `LivingDropsEvent`), reobf-verified.
- Live proof green on Forge 1614: mining custom ore drops gems per
  table, killing a beast drops its gem, world == pure union
  otherwise (drops are entities, not cells — the anvil verdict is
  unchanged).

## What would re-open it

- Drop modifiers (fortune, looting): new pure fields + gate, same
  seam — addendum here.
- A loot consumer outside harvest/kill (fishing, chests): new hook
  spec, same `DropStore` shape or a named sibling.
- Items per harvest: landed (content-decides tranche, hub
  decisions/SPAWN.md — the mob's `drop_count` seals `LootTable.count`,
  the bridge transports it, `LOOT_COUNT` constant gone).
- Ore scope: landed (operator-override tranche, hub decisions/SPAWN.md
  — the ore is the packs.cfg wire-block column, the `LOOT_ORE`
  constant is gone, unresolvable wire blocks still refuse under the
  kept `E_LOOT_ORE` code).
- State-id vocabulary: landed (hub
  decisions/SPI_STATE_VOCABULARY.md — the seal resolves the
  pack-served vocabulary through the SPI registry, same T4
  pack-driven re-opener as spawn).
