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
  `bridge-1710/java/src/fr/iamacat/bridge/spike/MinedStore.java:1-71`):
  `record(cell, tick)` on break events (latest break wins),
  `claimDue(now, delay)` (claimed cells leave the store),
  `sealed()` copy for snapshot states.
- `RepopJob` (pure, `RepopJob.java:1-62`): reads `spike:mined`
  (cell to mined tick) plus `spike:delay` from the snapshot, emits
  cells with `minedTick + delay <= tick`. Missing/wrong-typed states
  refuse loudly (`E_SPIKE_REPOP:*`), never defaulted.
- `RepopSeal` (pure, `RepopSeal.java:1-46`): per-tick seal of the
  store into snapshot states (`spike:mined` copy + `spike:delay`).
  The forge side wraps it with `ForgeSnapshot.snapshot` — the
  snapshot choke point stays the single factory, SPI untouched
  (the decoration question is decided: no `decideAll` change, no
  re-pin over 4 bridges).
- Forge hook (`bridge-1710/forge/.../MatouBridgeMod.java`, same 3-file
  set, `E_SPIKE_*` only so parity holds): `onBreak` (`:101`)
  records server-side dim-0 stone breaks as `Cell`-rendered volume
  cells at the last server tick (isRemote echoes ignored — the server
  fires its own event; other dims/blocks out of spike scope, not
  errors); `repopTick` (`:140`) seals, pure-decides, lands due cells
  through `WorldCellSink`, then `claimDue` and a loud
  `E_SPIKE_SEAL:diverged` tripwire when live claim != pure decision.
  Repop delay `REPOP_DELAY = 200` (`:57`), stone
  `REPOP_BLOCK = "minecraft:stone"` (`:60`), resolved fail-fast at
  init (`:70-73`), second bus registration (`:76`).
- Gate `RepopCheck` (`java/test/.../spike/RepopCheck.java`), wired in
  `bridge-1710/tools/check.sh:48` etage 1: store semantics, seal
  contents + copy isolation + refusals, job boundary
  (`minedTick + delay == tick` is due), refusals, plus the
  store-vs-job comparateur (claim == decision tick by tick, 95..145)
  routed through the shipped `RepopSeal`.
- Build: `run-live.sh` pins the new surface (isRemote SRG field,
  6 `BlockEvent`/`EVENT_BUS` universal presence pins) and compiles
  `java/src` into the forge classes dir (reobf-verified: vanilla
  refs remapped, e.g. `isRemote` to `field_72995_K`, Forge refs pass
  through); hub `run-client.sh` DEV forge compile gains the same
  spike stage (absent dir = other bridges compile as before).
- `E_SPIKE_*` codes stay spike-local (never in the `E_FORGE_*`
  parity catalog); the forge file-set is unchanged (hook lives in
  the existing `MatouBridgeMod.java`), so `check-bridges.sh` parity
  holds over all 4 bridges unchanged.

## Gates

- `./tools/dev-loop.sh --bridge ../bridge-1710` E0 green
  (hub check + bridge etages 1+2 + `ok spike-repop : all`).
- `tools/check.sh` green (index lists this file).
- Live-build replica green without booting the server: 17/17 pins
  (11 legacy + isRemote + 5 BlockEvent/EVENT_BUS), stub compile with
  the spike linked, no stub leak, reobf jar carries
  `onBreak`/`repopTick`/`RepopSeal`.

## What remains (re-opens as spec, not silently)

1. Live proof: mine → wait delay → world shows the block back
   (verdict = union + repop, vanilla stone).
2. Only then: registration (real custom ore), `Vein` genre (SYNTAX-V4),
   `Loot`, `Spawn` — each its own spec tranche on this proven seam.
