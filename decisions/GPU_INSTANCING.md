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
    Forge 2860. E0 LANDED 2026-09-11 (stages 1-2 green, live proof TODO —
    same bar as every lead E0).
2. 1165/1201 adapters after the first green (`RenderSystem`,
    `RenderLevelStageEvent` rewrites — hook only, the pure plan is untouched).
3. The engine GL 4.5 path is explicitly NOT ported (needs its own context).

## Addendum — render plan adapter E0, lead bridge-1122 (2026-09-11)

Lands the `render:*` wire the spike deliberately left out: the pure
plan is now snapshot-driven end to end on the lead, and the 2860
renderer draws through it (one instanced draw per bucket instead of
one draw for every living beast). Stages 1-2 green on the lead, live
proof TODO — same bar as every lead E0.

- SPI contract (spi `89406af`, additive — no existing view touched,
  no reseal): `RenderStates` (`SCOPE=render`, roles `eye`/`matrix`/`recs`
  in seal order, `vocabulary(namespace)` plus typed resolvers, same
  content-blind shape as `SpawnStates`/`LootStates` — the sealed shapes
  are named once here: `double[3]` camera world pos, `float[16]`
  row-major view-projection, list of `InstanceBucket.Rec`) ;
  `render.ViewProjection.vpRowMajor(viewCol, projCol)` (the single
  driver-to-plan conversion: both GL column-major matrices transpose
  once, then row-major `P * V` — fresh array, never aliased, loud
  `E_RENDER_MATRIX:null/shape`, SPI-owned like the other `E_RENDER_*`,
  outside the bridges' scanned trees, cited here). `VocabularyCheck`
  gains the render battery (scope, seal order, resolvers, cross-domain
  refusal); `RenderPlanCheck` gains the product goldens (identity,
  column-major translation, two-sided scale-over-translate, unit-cube
  frustum through the product, freshness, refusal battery) —
  `ok render-plan : 589 checks`.
- Bridge harness, lead only (bridge-1122 `4119639`): `RenderJob`
  (`fr.iamacat.bridge.render`, `MatouJob<Map<bucket, indices>>` over
  the `matoubridge.render` namespace — bridge-owned like `RepopJob`:
  the plan inputs are per-frame runtime reality, never content tables,
  so no pack serves them and no `PolicyPack` grows a camera-math
  accessor; the namespace rides the frozen `matoubridge` modid, hub
  `NAMES.md`, identical on all four runtimes by construction) plus
  `RenderSeal` (defensive-copy seal beside no pack states, plus
  `boundRadius` — the enclosing sphere of the sealed hitboxes around
  the entity origin, so the cull never clips a limb the hit-tester
  still serves) ; `RenderWireCheck` battery (vocab provision, seal
  copies + immutability, foreign-vocab refusal, radius goldens, decide
  goldens over the identity clip cube — culled key absent, visible
  indices in record order, determinism — full refusal battery), wired
  in `tools/check.sh`. The 2860 renderer seals every living beast per
  frame (mob-addressed model keys over the single shared mesh —
  per-mob meshes plug into the same keys — flat-`tint` texture key,
  V1 shader path) and draws the decided buckets (per-bucket repack,
  `E_GL_DRAW` drain-then-judge per draw, the `drew instances=` line
  kept with a `buckets=` suffix). Zero new MC surface (every member
  read was already pinned — no stub or narrow-map delta) and zero
  behaviour change for fully visible scenes (one bucket per mob over
  the same mesh, same bytes uploaded).
- Siblings mechanical re-pin only (1710 `6a4b523`, 1165 `038e893`,
  1201 `961a5b3` to `89406af` — additive, E0 green each, no live
  re-proof): their renderers are untouched, so their cells stay TODO
  with this addendum as the dispatch-port rationale, never silent.
- `PORT_QUEUE` new row `Render plan adapter` (`BRIDGE_PARITY.md`):
  `TODO | e0 | TODO | TODO`.
- Parity gap (dim 4, declared here): `E_RENDER_JOB` (job shape
  refusals) + `E_RENDER_SEAL` (seal + bound refusals) exist on 1122
  only until the dispatch ports land them on the siblings; no new
  `E_FORGE_*`, no new `forge/src` file, no new SPI error-code family
  beyond the cited `E_RENDER_MATRIX`.
- Named follow-ups blocking live (not silent): 150 s server re-proof
  (renderer is client-only — regression only) + headless
  direct-client `SPAWN=1 COMBAT=1` legs proving the wired draw
  (`drew instances=` with buckets, census 2→8, exact-2.0 + exact-3.0
  intact, saves pure union, zero `E_*`). CLOSED 2026-09-11 below
  (zero live fixes — the bridge stays `4119639` + `1b7dc7e`).

## Addendum — render plan adapter live, lead bridge-1122 (2026-09-11)

`bridge-1122` `4119639` (E0) + `1b7dc7e` (pin) proves the planned
draw live on Forge 2860 (150 s server + launcher-free headless
direct-client `NUMERIC_IDS=example1:my_ore=253 SPAWN=1 COMBAT=1` run,
Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — renderer client-only, regression leg only,
  zero `E_*`).
- Client: `ready mesh=72 verts stride=8` (the SPI bake, `program=12`)
  then `drew instances=1 mesh=72 verts buckets=1` — the first planned
  draw through the seal (one mob-addressed bucket over the shared
  mesh, GL accepted, `E_GL_DRAW` silent; a single visible beast on the
  first drawn frame, the culled rest cost nothing — cull sets stay
  gate-proven, the wire stays replay-identical); census 2→8 balanced
  (`beast=brute`, cap 8) at worldTicks 2..5, `spawn hp <my_beast
  20.0>` + `spawn hp <my_brute 30.0>`, exact-2.0 at 500→501 then
  exact-3.0 at 600→601 (elapsed 1 each, full-health brute baseline
  30.0 → 27.0 this run), spawn kill at 1000 → carrier tick 999 → gem
  polled at 1001 (elapsed 1) with the replacement joining the same
  tick, clean shutdown ; `verify-client-save.sh` world == pure union
  (1274 cells, `1,253` via `NUMERIC_IDS`) ; zero `E_*` / linkage (the
  only `Caused by` lines are the known benign gem-model bakes —
  missing `models/item/my_gem.json` + `my_brute_gem.json`, same
  signature as every 1122 proof since item registration).
- Trouvaille (live ops, no code impact): the first drawn frame kept a
  single beast — pig-AI wander plus a fixed camera means the visible
  set varies frame to frame by design (the `drawLogged` line fires
  once, so later fuller frames stay quiet). Per-frame plan/drop
  logging would trade log spam for a count nobody asserts (pixel
  proof stays refused) — not added.
- `PORT_QUEUE` row `Render plan adapter` flips to
  `TODO | live | TODO | TODO` (lead live, three dispatch ports TODO —
  the `E_RENDER_JOB` / `E_RENDER_SEAL` dim-4 gap names them).
