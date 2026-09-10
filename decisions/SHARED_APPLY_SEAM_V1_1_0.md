---
type: spec
status: active
maturity: standard
scope: shared
roadmap: -
---

# Shared apply seam v1.1.0 — `fr.iamacat.bridge` lives in SPI

Date: 2026-09-09 (reconstructed; landed in spi `0073226`, tracked in hub
`63ce116`)
Status: active

## Problem

Every bridge re-implemented the same decide→apply walk (cell codec,
snapshot seal, pack merge, reflective loading). N copies of one pure
algorithm means N places for a quiet divergence — and the divergence
that matters (a cell applied where the pure union says nothing stands)
only shows up inside a live Forge run, hours after the commit that
caused it.

## Decision

One seam, owned by SPI, imported by all bridges. The package
`fr.iamacat.bridge` lives in `spi/java/src/fr/iamacat/bridge/` with
FQNs unchanged by the move, so bridges re-point by import instead of
by copy:

- `CellSink.java:14` — apply seam interface; `setCell(x,z)`,
  `setBlock(x,y,z,block)` (default refuses).
- `ForgeCells.java:40,60,85` — pure cell codec + apply;
  `parseCell`, `parseBlockCell`→`BlockCell`,
  `applyCells(cells,sink)`.
- `ForgeSnapshot.java:22` — decide-seam choke;
  `snapshot(tick,states)`→`Snapshot` (refuses `tick<0`).
- `ForgeContent.java:29,50,75` — orchestrator; `merge`,
  `decideAll(pack,tick)`, `applyAll(pack,tick,sink)`.
- `Packs.java:49,108,146` — reflective loading; `parseLines`,
  `load`, `loadConfigured`+`PackSpec`.
- `SpiBridge.java:22,35` — M1 skeleton; `tick(snap,job)`
  (decide→applied), `applied()`.

Each bridge keeps only its version-native edge: `MatouBridgeMod.java`
(mod entry), `PackWire.java` (SPI→Block bind, imports
`fr.iamacat.bridge.*`), `WorldCellSink.java` (native sink). No
`ForgeCells/Content/Snapshot/Packs/CellSink` copy may exist bridge-side.
`ForgeContentCheck` stays per-bridge
(`bridge-*/java/test/fr/iamacat/bridge/ForgeContentCheck.java:23`) —
the pure E2E against `../example1` is what proves the re-point did not
shift behaviour.

## Gates

- `spi/tools/check.sh` runs
  `spi/java/test/fr/iamacat/bridge/BridgeCheck.java:21`: decide-apply
  walk + immutability, `parseCell`/`parseBlockCell`/`applyCells`
  (incl. 2D-sink-refuses-3D and `E_BRIDGE_*` recode), snapshot seal,
  `Cell` codec, typed `Snapshot` accessors, `Counts`,
  `Packs.loadConfigured`.
- All four `bridge-*/SPI_PIN` read
  `00934e1fc84317725cf478fea3d5380c8075e76b`
  (`tools/check-bridges.sh` refuses any drift).
- Live re-proof after the move: world == pure union, same 1274-cell
  count on 1614/2860/47.2.0/36.2.42.

## What would re-open it

- A seam method needing a version-specific shape: overload in the
  bridge sink, never a fork of the SPI file.
- A second shared package: same treatment (move up, re-point, E2E
  stays), recorded here as an addendum.
