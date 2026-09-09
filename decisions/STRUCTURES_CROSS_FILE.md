---
type: spec
status: active
roadmap: -
---

# Structures + cross-file parts — recursive volumes, strict wiring

Date: 2026-09-09 (B4/B5/B6, reconstructed from pack + gate + live)
Status: active

## Problem

Point placements (`feature`) cannot build a hut: multi-block volumes
need recursion (parts of parts), palette indirection (content-ref →
landable block), and composition across files (a hut referencing a
well in another file) — with cycles and dangling refs refused at
parse time, not as missing blocks in a live world.

## Decision

`StructurePlaceJob` (example1, 436 lines, `:19-27` contract): one
volume plus recursive `parts` (SYNTAX-V3), own volume placed first
then parts depth-first sharing one plane offset, palette aliases
strict both ways (identity when empty), oversize
(`E_EXAMPLE_SIZE`) / empty palette (`E_EXAMPLE_PALETTE`) refused,
cross-file cycles refused (`E_EXAMPLE_PARTS:cycle` with a qualified
chain — never defaulted).
`ExamplePack.fromFiles` (single `:164+` over list overload):
`structureFiles` lists extra content files, `structureRoot` names
the qualified root (`ExamplePack.java:47-48,134-150`); the whole
cross-file tree wires once with palette aliases strict over every
file — unreadable / unknown namespace / missing structure /
unmapped palette / unknown alias all loud.
Imports are parser-enforced (`matou_parse.py:121-125,241`), so a
file cannot reference what it never imported.
Content: `structure.matou` (leaf `well` 3*2*3 = 18 cells +
composite `hut` with a differing part palette, landing order
block-labelled), `structure_cross.matou` + `structure_badparts.matou`
(cycle halves `far ↔ near`, negative goldens at the gate).
Proven twice: pure E2E gate (cross-file `ext`, 19 cells) then live
hut re-proof — 1274 cells, hut path byte-identical through the
multi-file machinery (STATE B6).

## Gates

- Pure E2E gate green (volumes, recursion, aliases, cycles,
  cross-file `ext`).
- Live re-proof: world == pure union, same 1274-cell count as the
  single-file proof — the machinery adds zero cells.

## What would re-open it

- A new placement primitive: new genre version-gated (V4 path),
  never a quiet field on `structure`.
- A second composition axis (e.g. biome-scoped parts): explicit
  wiring keys like `structureFiles/structureRoot`, never
  positional file order.
