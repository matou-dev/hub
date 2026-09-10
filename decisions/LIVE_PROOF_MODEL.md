---
type: ruling
status: active
maturity: unrated
scope: shared
roadmap: -
---

# Live proof model — bind clean + world == pure union

Date: 2026-09-09 (B3/C3/D3/E3, four runtimes, one verdict)
Status: active

## Problem

"It booted" proves nothing: a mod can load, tick, and place the
wrong blocks — or no blocks — while the log stays quiet. Without a
verdict contract, each new Minecraft version re-litigates what
"proven" means, and a green run on one version cannot be compared
to any other.

## Decision

Every live proof runs the same contract (`bridge-*/tools/run-live.sh`,
B3 shape at `bridge-1710:293-403`): flat world, wire y=63
(2D plane) + hut volumes y=64..65 (per-shape sensitive slices),
150s server run ending in timeout (early exit = loud FAIL), then
two verdict halves. Half one, bind clean: no `NoSuchMethodError` /
`NoSuchFieldError`, no `E_FORGE/E_BRIDGE/E_EXAMPLE/E_REG`, no unexpected
exception, and the mod string present in the boot log
(`:321` "bind clean, ticks clean"). Half two, world == pure union:
`CellUnion` replays the pure decision union from `packs.cfg`
(4000 ticks), `anvil.py` reads 6 chunks (0..1, -1..1) × 3 slices
off the region files, and the comparison demands per-name ID groups —
plane cells under the wire block (custom ore: runtime ID resolved
dynamically from the boot-log registration line, never hardcoded),
volume cells under their landable names — nothing foreign, nothing
missing (`:323-403`). The verdict owns
the exit status. Same content + same seam = same count: 1274
cells on 1614, 2860, 47.2.0 and 36.2.42 — the fourth runtime
proves the model, not just the port (pre-registration era: stone
only; since registration: ids 1,165 on 1614, positions unchanged).

Per-version notes, measured live never assumed: C3 derives a
4-line narrow MCP→SRG map from pinned vanilla server +
joined.tsrg + javap, with Forge-added `getDimension` an explicit
passthrough (1122 `run-live.sh:128-141`); D3 is Mojmap classes +
SRG members (installer MERGE_MAPPING chain, mcp_config
joined.tsrg v2 + javap, 1201 `:180-190`), ships FAT
(NoClassDefFoundError found live — ModLauncher isolates every
mods/ jar), mirrors stub annotations at RUNTIME retention
(invisible `@SubscribeEvent` registered nothing, silently), and
reads palette format incl. nested lists / single-valued sections /
signed bytes; E3 matches the MCP model with a snapshot name lock
(three same-type static `RegistryKey` fields — descriptor alone
cannot pick OVERWORLD, 1165 `:168-172`), FAT + `mods.toml`, an
erased-descriptor `IForgeRegistryEntry` bound, `Level.Sections` /
`Palette` / `BlockStates` anvil reads, and pool-resolving javap
checks (JDK8 prints annotations as pool refs).

## Gates

- 150s run, bind clean, world == pure union (1274 cells, per-name IDs)
  — all three must hold; any one failing is a red proof.
- A new version claims parity only by landing the same count,
  never by argument.

## What would re-open it

- Different proof geometry: re-derive the slice/chunk read
  explicitly at both use sites (server verdict + client
  verifier), never widen silently.
- A runtime where the verdict tooling itself drifts (new anvil
  format): the probe learns it loudly, the union stays pure.
