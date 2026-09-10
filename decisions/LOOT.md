---
type: spec
status: direction
roadmap: -
---

# Loot — event-sourced drops on the repop seam

Date: 2026-09-10
Status: direction (contract frozen, code TODO)

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
parity (basenames + `E_FORGE_*` only) holds with behaviour
1710-only until proven.

Explicit non-goals for tranche 1: fortune/silk-touch modifiers,
conditional tables (biome, moon phase), experience orbs.

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
