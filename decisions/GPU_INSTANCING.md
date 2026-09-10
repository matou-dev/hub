---
type: direction
status: active
maturity: prototype
scope: spi
roadmap: -
---

# GPU instancing — pure render-planning spike, GL adapters later

Date: 2026-09-10
Status: active

## Problem

Two upstream GPU infras exist in the old org (`/home/iamacat/Documents/GitHub/matou/`)
with opposite portability (measured on imports + callsites, 2026-09-10):
`matoulib-core/.../client/gpu/` draws through `glDrawArraysInstancedARB` +
`gl_InstanceID` (`GeoInstancedRenderer.java:37,40,262`) — a GL2-era path
valid on all four runtimes — but its 1.7.10 MC/Forge imports
(`GeoInstancing.java:12-17,24`: `OpenGlHelper`, `RenderWorldLastEvent`,
`cpw.mods.fml`) need a per-version port each; `matou-engine/.../render/gl/`
(`GlDevice.java:6-18,610,646`) is GL 4.5 core standalone (DSA, indirect
multi-draw) and cannot live inside any MC GL context. No bridge touches GL
until the portable half is proven shared, pure, and gated — otherwise each
bridge grows its own bucket layout and the four draws silently disagree.

## Decision

Spike scope is pure render planning in SPI (`fr.iamacat.spi.render`), zero MC,
zero GL, no live proof:

- `Frustum` (`spi/java/src/fr/iamacat/spi/render/Frustum.java:1-166`):
  Gribb-Hartmann extraction (`of`, `:60`) from a row-major float[16],
  normalised planes, camera-relative tests (`testAabb` two-corners `:113`,
  `testSphere` six dots `:145`). Derived from matou-engine
  `core/view/Frustum.java` with two documented deviations: classic GL depth
  (`w +/- row` all six, near = w + row2 — the mirror trap of the engine's
  reverse-Z planes, which would cull the near half of every MC view) and a
  Java 8 backport (`--release 8`, no switch-expr).
- `InstanceBucket` (`InstanceBucket.java:1-123`): `Rec` (opaque model/texture
  keys + world doubles + sphere + yaw, `:38`) and `plan` (`:78`) bucketing
  `(model, texture)` in first-seen `LinkedHashMap` order (translucent-overlap
  parity, as `GeoInstancing#record`), GPU order inside (bucket all, then drop
  culled per bucket). The eye is subtracted in double before narrowing
  (the engine `CameraView` rule — float-direct at 1e8 rounds neighbours onto
  the eye and keeps gone mobs). Absent key means fully culled.
- Deliberately NOT snapshot-driven: no `Snapshot`/`MatouJob`, no `render:*`
  states, no vocabulary/provision touch. The `render:*` wire lands with the
  first GL adapter, not here.
- Thrown set (PORT_QUEUE-declared, `decisions/BRIDGE_PARITY.md`):
  `E_RENDER_FRUSTUM:null/shape/degenerate`, `E_RENDER_PLANE:range`,
  `E_RENDER_AABB:nan/range`, `E_RENDER_SPHERE:range/nan`,
  `E_RENDER_REC:key/nan/radius`, `E_RENDER_PLAN:null/nan`. SPI-owned codes
  outside the bridges' scanned trees; cited here so no adapter redefines
  them per version.
- Gate `RenderPlanCheck`
  (`spi/java/test/fr/iamacat/spi/render/RenderPlanCheck.java`, wired in
  `spi/tools/check.sh:23`): ortho goldens lock row-major + classic depth
  (exact floats), perspective behaviour, the 1e8 eye trap (double culls,
  float-direct control keeps), refusals battery, plus two comparateurs:
  oracle-OUTSIDE ⟺ clip-space 8-corner brute force over seeded boxes
  (512 x 2 matrices, incl. the locked all-corners-outside-yet-INTERSECT
  false positive — costs a draw, never a missing mob), and bucket-then-cull
  vs cull-then-bucket over seeded scenes (same visible sets per bucket, key
  order stable first-seen-over-all).

## Gates

- `spi/tools/check.sh` green incl. `ok render-plan : 580 checks`.
- `hub/tools/check.sh` green (index lists this file, parity over 4 bridges
  unchanged — no bridge file touched, no live re-proof).
- 4 bridges re-pinned to the spike SPI (mechanical, scaling-audit precedent:
  decided bytes identical, E0 green each, no live re-proof).

## Measured on the way (shipped path, never assumed)

- The order comparateur failed first run red on purpose-shaped scenes: a
  bucket whose first records cull out sits earlier (first-seen over all)
  than cull-first places it. Real semantic fork, not a bug: sets must agree
  (cull correctness), order stays stable (no draw-order popping as mobs
  cross planes). The contract now asserts both halves separately.

## What remains (re-opens as spec, not silently)

1. 1122 GL adapter: `render:*` snapshot states + vocab, 2860-native hook
   (same GL era as the derived path — cheapest live proof), live proof on
   Forge 2860.
2. 1165/1201 adapters after the first green (`RenderSystem`,
   `RenderLevelStageEvent` rewrites — hook only, the pure plan is untouched).
3. The engine GL 4.5 path is explicitly NOT ported (needs its own context).
