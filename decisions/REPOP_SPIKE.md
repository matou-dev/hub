---
type: direction
status: active
roadmap: -
---

# Repop spike — event-sourced repop on vanilla, registration-free

Date: 2026-09-09
Status: active

## Problem

Every ORespawn delta (veins, loot, mobs) assumes one unproven seam:
mined-state flows back into pure decisions without breaking the
`MatouJob` purity contract (`MatouJob.java:6-9` — no IO, no clock, no
mutable statics). A `StatefulJob` with hidden mutables would pass every
gate and poison determinism (same snapshot in must give equal decision
out). The seam must be measured before registration/veins are specced.

## Decision

Event-sourcing, spike-scoped to vanilla stone (zero registration):

- `MinedStore` (bridge-owned, plain data, zero MC,
  `bridge-1710/java/src/fr/iamacat/bridge/spike/MinedStore.java:1-65`):
  `record(cell, tick)` on break events (latest break wins),
  `claimDue(now, delay)` (claimed cells leave the store),
  `sealed()` copy for snapshot states. The forge break-event hook and
  the per-tick seal are NOT in this tranche — named below.
- `RepopJob` (pure, `RepopJob.java:1-64`): reads `spike:mined`
  (cell to mined tick) plus `spike:delay` from the snapshot, emits
  cells with `minedTick + delay <= tick`. Missing/wrong-typed states
  refuse loudly (`E_SPIKE_REPOP:*`), never defaulted.
- Gate `RepopCheck` (`java/test/.../spike/RepopCheck.java`), wired in
  `bridge-1710/tools/check.sh:48` etage 1: store semantics, job
  boundary (`minedTick + delay == tick` is due), refusals, plus the
  store-vs-job comparateur (claim == decision tick by tick, 95..145).
- `E_SPIKE_*` codes stay spike-local (never in the `E_FORGE_*`
  parity catalog); `forge/` untouched, so `check-bridges.sh` parity
  holds over all 4 bridges unchanged.

## Gates

- `./tools/dev-loop.sh --bridge ../bridge-1710` E0 green
  (hub check + bridge etages 1+2 + `ok spike-repop : all`).
- `tools/check.sh` green (index lists this file).

## What remains (re-opens as spec, not silently)

1. Forge hook: break-event subscribe feeding `MinedStore`, per-tick
   seal into snapshot states beside `pack.states(tick)`
   (`ForgeContent.decideAll` decoration — SPI untouched or extended
   by spec, decided then).
2. Live proof: mine → wait delay → world shows the block back
   (verdict = union + repop, vanilla stone).
3. Only then: registration (real custom ore), `Vein` genre (SYNTAX-V4),
   `Loot`, `Spawn` — each its own spec tranche on this proven seam.
