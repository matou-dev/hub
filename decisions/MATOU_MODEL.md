---
type: spec
status: active
maturity: prototype
scope: spi
roadmap: -
---

# MatouModel — declarative Bedrock geometry in SPI, VBO mesh and hitbox bake

Date: 2026-09-11
Status: active

## Problem

Two consumers need the same beast shape and disagree by construction:
`bridge-1122/.../forge/InstancedMeshRenderer.java:65` hardcodes a
`BOX_VERTICES` placeholder box (0.9 high, dummy UVs), while virtual
hitboxes (`decisions/VIRTUAL_HITBOXES.md`) expect hand-written `BoneBox`
lists per entity. Every new mob would duplicate its dimensions twice —
once as mesh floats, once as collision boxes — and the two copies drift
silently (the Conventions-divergence class: no dériveur, no comparateur).

## Decision

The shape lives once, as a Blockbench Bedrock geometry file, parsed and
baked purely in `matou-spi` (`fr.iamacat.spi.model`, Java 8, zero MC,
zero GL, zero dependency). Bridges consume the bake, never the file.

- `JsonParser.java`: minimal JSON reader (objects, arrays, strings with
  escapes, numbers as Double, true/false/null). org.json/Gson cannot
  enter SPI; the geometry subset needs nothing more.
- `ModelCube.java`: origin (min corner, px), size (px, > 0 after
  inflate), box UV anchor (px, >= 0), inflate (px, expands every side).
- `ModelBone.java`: name, optional parent, bind-pose pivot (px,
  informational in V1), cubes in file order.
- `MatouModel.java`: identifier, texture grid, bones. Single derivation
  point: `bakeMesh()` feeds the renderer VBO, `boneBoxes()` feeds
  `HitTester`.
- `MatouModelParser.java`: first entry of `minecraft:geometry` wins;
  multi-geometry files split before import. Bone parents validate
  against the model bone set (forward refs allowed). Per-face `uv`,
  `rotation` and `mirror` beyond acceptance are NOT baked (see below).
- Frozen Bedrock subset: `format_version` string (value recorded,
  ignored), `description.identifier` (required), `texture_width/height`
  (integral, 1..4096), bones (`name` unique non-blank, `parent`
  optional, `pivot` optional [x,y,z]), cubes (`origin`/`size`
  required [x,y,z], `uv` optional [u,v] default [0,0], `inflate`
  optional default 0, `mirror` accepted and ignored).
- Bake rules: pixels in, block units out (`PX_PER_BLOCK = 16`); one
  `BoneBox` per non-empty bone (union of its inflated cubes,
  entity-local, bind pose); `bakeMesh` emits 36 interleaved vertices
  per cube (`VERTEX_STRIDE = 8`: pos3, uv2, normal3 — the exact layout
  `InstancedMeshRenderer` uploads); faces bake in bind pose,
  axis-aligned, CCW with outward normals, corner order mirroring the
  live-proven box; UVs are box-anchored planar projections of the cube
  rect (V1 shader tints and ignores them — per-face unwrap lands in V2
  with texture sampling).
- Thrown set (SPI-owned, cited here so no bridge redefines them):
  `E_MODEL_JSON:empty/syntax/type`, `E_MODEL_VERSION:missing`,
  `E_MODEL_GEOMETRY:missing/shape`, `E_MODEL_IDENTIFIER:missing`,
  `E_MODEL_TEXTURE:shape`, `E_MODEL_BONE:empty/shape/duplicate/parent/pivot`,
  `E_MODEL_CUBE:null/shape/origin/size/uv/nan`.
- Gate `ModelCheck`
  (`spi/java/test/fr/iamacat/spi/model/ModelCheck.java`, wired in
  `spi/tools/check.sh`): parse goldens (2-bone beast, empty model,
  defaulted cube), bake fidelity (vertex count, first-vertex
  pos/uv/normal, head UV anchor), winding comparateur (cross-product
  normal of all 24 triangles dots the declared normal — proves
  outward CCW, i.e. no culled beast), `boneBoxes` union + inflate
  goldens with `HitTester` bone resolution (front ray -> body, high
  ray -> head), refusals battery over the whole `E_MODEL_*` catalog.

## Gates

- `spi/tools/check.sh` green incl. `ok model-check`.
- `hub/tools/check.sh` green (index lists this file; no bridge file
  touched, no live re-proof — pure SPI tranche, GPU_INSTANCING
  precedent).
- 4 bridges re-pinned to the model SPI (mechanical, scaling-audit
  precedent: decided bytes identical, E0 green each, no live re-proof).

## What remains (re-opens as spec, not silently)

1. Bridge consumer: replace `BOX_VERTICES` with `bakeMesh` output and
   feed `boneBoxes` to the entity `Hittable` (lead bridge first, then
   PORT_QUEUE ports).
2. Per-face `uv` + texture sampling in the instancing shader (V2).
3. Bind-pose rotation/pivot bake and animation tables (later tranche).
