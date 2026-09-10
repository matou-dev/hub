---
type: note
status: active
maturity: unrated
scope: shared
roadmap: -
---

# Scaling audit — structural fix, behaviour-preserving

Date: 2026-09-09 (audit closed green, no red gate; landed as spi
`00934e1` / example1 `c0778ba` / minimap `77bdb0b`, 4 bridges
re-pinned)
Status: active

## Problem

No gate was red, but three metrics tripped the audit threshold:
`ExampleCheck` toward 840 lines of near-identical refusal cases, a
MatouParse-adjacent cell codec triplicated across spi consumers
(every caller re-splitting cell strings by hand), and positional job
indexing (`jobs().get(0)` meaning "owned" by convention, silently
wrong the day the order moves). Each is the class that scales
linearly with every new content file — cheap today, lockstep bloat
tomorrow.

## Decision

Structural fix, behaviour-preserving, three tranches:

- SPI shared authoring surface (spi `00934e1`): `Cell`
  (`spi/Cell.java:14`, `of/parsePlane/parseVolume/parse`
  `:32-114`) owns both cell shapes once; `Counts`
  (`spi/Counts.java:12-24`) owns count-code checks; typed
  `Snapshot` (`spi/Snapshot.java:12`) replaces raw maps;
  `Packs.loadConfigured` (`bridge/Packs.java:146-165`)
  instantiates + configures in one named step (args to a
  non-configurable pack refused, never silently dropped);
  `AUTHORING.md` maps goal to interfaces so the next test mod's
  first cut is the right one.
- example1 registry + table gate (example1 `c0778ba`):
  `ExampleIds` (`ExampleIds.java:12-32`) holds every
  `namespace:name` once (RNG addresses derive from these ids);
  `ExamplePack.job(id)` (`ExamplePack.java:367-384`) resolves by
  id with loud refusal on unknown — callers never index `jobs()`
  positionally; jobs read shared `Cell`/`Counts`; the gate goes
  table-driven (`ExampleCheck.java:65-71` refusal loops, 821
  lines and falling per case added as a row, not a block).
- minimap slim + boundary golden (minimap `77bdb0b`):
  `MinimapJob` (71 lines, `MinimapJob.java:31-42`) reads shared
  `Snapshot`/`Cell` with `MAX_RADIUS = 8`; the gate pins the
  max-radius boundary (`MinimapCheck.java:114-123`: 17 rows, all
  void, still pure).

4 bridges re-pinned to `00934e1` with the merge comparateur still
green — no live re-proof: decided bytes identical, gates lock them.

## Gates

- All sibling gates green post-refactor (spi `BridgeCheck`,
  example1 content gate, minimap check, 4 bridge etages 1+2).
- No behaviour change: goldens and live verdicts untouched
  (1274-cell union stands).

## What would re-open it

- A second codec copy outside `Cell`: delete it, never a fourth.
- A new positional `jobs().get(N)`: same treatment as `job(id)`.
- `ExampleCheck` crossing ~450 lines again: table-drive further
  (AGENTS.md file-size alert), never a split satellite.
