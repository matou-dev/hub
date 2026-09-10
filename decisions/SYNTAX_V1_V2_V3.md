---
type: spec
status: active
maturity: standard
scope: shared
roadmap: -
---

# Syntax V1/V2/V3 — frozen deltas, dual-parser goldens

Date: 2026-09-09 (S1/S2/S3/S4, reconstructed from specs + gates)
Status: active

## Problem

A hand-written grammar per content file drifts with every author:
version guessing, silent defaults, unqualified refs resolving by
luck. CatzEngineNext measured the fix (CATZ_SYNTAX_V2, P61-P65): one
schema-driven grammar, frozen, with the oracle shared by every
implementation — never prose agreement between two parsers.

## Decision

`spi/spec/SYNTAX-V1.md` (64 lines, FROZEN): `.matou` UTF-8, first
line `syntax 1` (any other number refused, no guessing), `#`
comments, fixed 2-space instance indent, fail-fast `E_MATOU_*`
`CODE:LINE`, bare idents refused (every ref `namespace:name`),
one `namespace` per file, `from x use …` imports, closed 4 genres.
`SYNTAX-V2.md` (39 lines, delta only, V1 untouched): signed ints,
`vec3`, `list<T>` — foundation types with zero business semantics,
every future genre needs them. `SYNTAX-V3.md` (39 lines, delta
only): `structure` genre version-gated (`syntax 3`; the reference
parser accepts 1..3), fields `anchor/size/palette/parts/count`.

Reference parser `spi/parser/matou_parse.py` (275 lines, zero MC):
fail-fast first-error-wins, imports recorded (`:121-125`) and
enforced (`:241` — ref outside local ns and imports refused).
Port Java `spi/MatouParse.java`: same grammar, same refusals; any
divergence is named by the gate (S2), never absorbed.
`spi/tools/check_goldens.py` runs BOTH sides over every golden
(`:72-73` runners py + java): `.expected.json` structural tree or
`.expected.txt` `CODE:LINE`. 18 `.matou` goldens (S1 9 → S3 14 →
S4 18 as types landed). Refusal parity is byte-named:
`err_ref_bare.matou` (bare `drop = fang`) → `E_MATOU_TYPE:16` from
both parsers — the M2 gate then held the same bar for content
packs.

## Gates

- `check_goldens.py` green on both runners; a Java divergence fails
  loudly with its name (S2 proved the teeth: one real bug found by
  goldens before freeze).
- Frozen specs: V2/V3 never edit V1 — delta files only.

## What would re-open it

- V4 (new genre or type): new `SYNTAX-V4.md` delta + goldens both
  sides, never a silent V1..V3 edit.
- A third implementation: it passes the same 18 goldens or it does
  not exist.
