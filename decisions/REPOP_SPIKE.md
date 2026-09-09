---
type: direction
status: done
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
- Proof companion (`bridge-1710/tools/autoplay/`, DEV ONLY, never ships,
  `SPIKE=1` arms it — unset = byte-for-byte the proven union run):
  server `WorldTickEvent` dim-0 mine at (8,10,8) (isolated coords outside
  the y=63..65 verdict slices, so the spike cell can never pollute
  world == pure union), `BreakEvent` post authored by the joined player,
  then poll back to stone (fail-fast `E_SPIKE_PROOF`, clean shutdown for
  post-mortem — the save keeps the air hole). Pins: want.txt +4 M
  (stone resolve, place, clear, poll) +3 F (dim filter, harvest author),
  universal-pin.txt +3 (WorldTick world, `post(`, Side SERVER); hub
  `run-client.sh` searge derive supports F lines (1710-scoped: only the
  srg-mcp branch, other eras untouched).

## Gates

- `./tools/dev-loop.sh --bridge ../bridge-1710` E0 green
  (hub check + bridge etages 1+2 + `ok spike-repop : all`).
- `tools/check.sh` green (index lists this file).
- Live-build replica green without booting the server: 17/17 pins
  (11 legacy + isRemote + 5 BlockEvent/EVENT_BUS), stub compile with
  the spike linked, no stub leak, reobf jar carries
  `onBreak`/`repopTick`/`RepopSeal`.
- Live proof GREEN on Forge 1614 (bridge-1710 `74d2fad`, host OpenJDK
  1.8.0_502) : `SPIKE=1` direct client run, simulated harvest at
  (8,10,8) — bridge recorded `<8,10,8:minecraft:stone>` at tick 999,
  repopped 1 cell at tick 1199 (delay exactly 200); companion poll saw
  stone back at worldTick 1201; y=10 anvil spot reads stone (numeric
  ID 1); final `verify-client-save.sh` green (world == pure union,
  1274 cells, stone only). Reconstruction: `AUTOPLAY=1 SPIKE=1`
  `run-client.sh` (stage + preseed) then `SPIKE=1`
  `run-client-direct.sh`, verdict = log greps + anvil spot + verifier.
- Measured on the way there (shipped path or its pins, never assumed):
  the integrated server ticks dim 0/1/-1 from boot (hence the dim-0
  filter, first run mined the Nether and failed loud); the BreakEvent
  constructor reads the player (ForgeHooks.canHarvestBlock — null NPEs,
  second run crashed, hence the joined-player author); stub `final int`
  folds into prod bytes (the hook recorded 0,0,0 for every break —
  `BlockEvent` ints de-finaled, `no-stub-const` gate in bridge
  `tools/check.sh` etage 1, other bridges swept clean).

## What remains (re-opens as spec, not silently)

1. Live proof : done 2026-09-09 (see Gates — verdict = union + repop,
   vanilla stone).
2. Registration (real custom ore), `Vein` genre (SYNTAX-V4), `Loot`,
   `Spawn` — each its own spec tranche on this proven seam.
