---
type: spec
status: active
roadmap: -
---

# Vein V4 — `vein` genre (SYNTAX-V4) plus pure cluster job

Date: 2026-09-10
Status: active (first consumer: example1 `VeinPlaceJob` + bridge-1710 live wire, live-proven 2026-09-10)

## Problem

`Feature{block:block_ref, count:u32}` (`goldens/valid_basic.matou:18-20`)
is a proto-vein: `OwnedVeinJob.java:26` reads the count
(`Counts.positive`, missing/bad/negative refused loudly) and scatters N
cells. There is no cluster shape — no size, no seed — and the V2
foundation types (`vec3`, `list<T>`, `i32`) have exactly one consumer
(`structure` in V3). A vein of registered ore needs a frozen cluster
contract before any placement code.

## Decision

`spi/spec/SYNTAX-V4.md` delta (V1..V3 untouched, per the V4 re-open rule
in `decisions/SYNTAX_V1_V2_V3.md:55-56`): first line `syntax 4`, the
reference parser accepts 1..4. New genre, v4-only:

- `vein`: `block:block_ref`, `count:u32`, `size:vec3`, `seed:i32`.
  Reuses `Feature.block`/`count` plus `Structure.size` semantics
  (`SYNTAX-V3.md:24-29`: parser accepts any ints, the deciding job
  refuses non-positive extents — same parser-syntactic/job-semantic
  split; empty palette refused by the job, same family). `seed` is a
  V2 `i32`, a deterministic salt — zero new types, zero new codes.

Parser hooks (both sides, same shape as V3):

- py (`spi/parser/matou_parse.py`): version regex `:74`
  `syntax ([123])` gains `4`; genre table `:12-13` gains
  `GENRES_V4 = GENRES_V3 + ("vein",)`; `allowed_genres` `:20-21`
  returns V4 at `syntax >= 4`; gating (`:127-133` genre decl,
  `:157-159` instance, `:145-146` field type) unchanged —
  `vein_ref`/`list<vein_ref>` fall out of the existing `valid_type`
  table.
- java (`spi/java/src/fr/iamacat/spi/MatouParse.java`): `P_SYNTAX`
  `:44-45` gains `4`; `GENRES_V4` beside `:25-27`;
  `DECL_BY_WORD_V4` beside `:63-72`; `declOf` `:80-82` returns V4 at
  `syntax >= 4`; gating (`:213-215`, `:252-254`, `validType`
  `:332-346`) unchanged.

Version gating mirrors V3 exactly: `genre Vein` or a `vein` instance
in a `syntax 1|2|3` file is `E_MATOU_GENRE` at that line; a `vein_ref`
field type in `1|2|3` is `E_MATOU_TYPE` at the field line.

Goldens (both runners, per `spi/tools/check_goldens.py` discovery):
`valid_v4_vein.matou` + `.expected.json` (structural tree) and
`err_v3_vein.matou` + `.expected.txt` (`E_MATOU_GENRE` at the genre
line) at minimum.

Pure `VeinPlaceJob` in `example1` (zero MC, same purity contract as
`OwnedVeinJob`): seeded clusters via `MatouRng.forAddress` over
(namespace, name, seed, tick); `count`/`size` arrive as snapshot
states and are refused `Counts`-style when missing/bad/non-positive;
a store-vs-job comparateur (spike-gate pattern) holds claim ==
decision tick by tick. It places the registered ore from
`decisions/REGISTRATION.md` — vein code lands on the registration
path, never on vanilla stone.

## Gates (will prove the tranche)

- `check_goldens.py` green on both runners (py + java agree, refusal
  parity byte-named like `E_MATOU_GENRE` for the v3-vein golden).
- E0 pure green: job boundary (`count`/`size` edges), refusals,
  comparateur green, etage 1.
- Live proof green on Forge 1614: clusters of `example1:my_ore` at
  seeded positions, the rest == pure union.

## What would re-open it

- y-range / biome / dimension filters: a V5 delta, never a silent
  `vein` field addition.
- Branch/tendril shapes: new job, same genre — recorded here as an
  addendum, not a parser change.
