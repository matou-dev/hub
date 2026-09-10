---
type: spec
status: direction
roadmap: -
---

# Spawn — event-sourced mob placement on the repop seam

Date: 2026-09-10
Status: direction (contract frozen, code TODO)

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
class follows the `decisions/REGISTRATION.md` path later and gets
its own addendum. Codes `E_SPAWN_*` tranche-local in the existing
`MatouBridgeMod.java`; `check-bridges.sh` parity holds 1710-only
until proven.

Explicit non-goals for tranche 1: custom entity rendering, biome /
dimension filters, despawn policy, pack AI.

## Gates (will prove the tranche)

- E0 pure green: `SpawnStore` census semantics, seal isolation, cap
  boundary (cap reached = no spawn, never negative), refusals,
  comparateur, etage 1.
- Live-build replica green: new event pins resolved, reobf-verified.
- Live proof green on Forge 1614: beasts appear up to cap at decided
  cells, kills pay out through the loot table
  (`decisions/LOOT.md`), world == pure union otherwise.

## What would re-open it

- Custom entity class + renderer: registration-path tranche, same
  seam.
- Filters (biome, light, depth) and despawn: new pure fields +
  gate, addendum here.
