---
type: direction
status: active
maturity: standard
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

1. 1122 GL adapter — DONE live 2026-09-11 (lead E0 + lead live addenda
    below, zero live fixes, `PORT_QUEUE` lead cell `live`), closed by
    the standard promotion.
2. 1710/1165/1201 adapters — DONE live x4 2026-09-12 (dispatch E0 +
    dispatch live addenda below, `PORT_QUEUE`
    `live | live | live | live`), closed by the standard promotion.
3. The engine GL 4.5 path is explicitly NOT ported (needs its own context)
    — stays the named non-goal.

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

## Addendum — render plan adapter dispatch E0, siblings 1710/1165/1201 (2026-09-12)

Stages 1-2 green on all three siblings, live proof TODO — same bar
as the lead E0. The pure plan is untouched (byte-identical
`RenderJob` + `RenderSeal` + `RenderWireCheck`, `cp`-copied from the
lead — the `RepopJob` identical-bytes precedent) ; only the forge
hook is version-native:

- 1710 `4e25e2a` (LWJGL2/cup): `event.partialTicks` field,
  `mc.theWorld`, `(Entity) mc.renderViewEntity` cast,
  `loadedEntityList`, `isDead`, `posX` family, `GL11 glGetFloat`
  matrices through the same `colMajor` + `vpRowMajor` conversion.
- 1165 `6c248e7` (LWJGL3/blaze3d): event `MatrixStack` + projection,
  `getInstance`, `ClientWorld.getAllEntities`, `getRenderViewEntity`,
  `prevPos`/`getPos` interpolation, `removed`, Mojang
  `Matrix4f.write` buffers fed as the column-major inputs (already
  GL-ready as uploaded today with `transpose=false`).
- 1201 `ac31b4c` (LWJGL3/JOML): `AFTER_ENTITIES`-gated
  `RenderLevelStageEvent`, `getPartialTick`, `getCameraEntity`,
  `EntityGetter` 64-box, `isAlive`, `xo`/`getX` interpolation,
  `getYRot`/`getXRot`, JOML `clear()` + `get()` (no flip) buffers fed
  as the column-major inputs.

Zero new MC surface on all three (no stub or narrow-map delta —
every member read was already pinned ; the added refs are
bridge/SPI/JDK only). `drawLogged` keeps the `drew instances=`
prefix with a `buckets=` suffix, same as the lead.
- `PORT_QUEUE` row `Render plan adapter` (`BRIDGE_PARITY.md`):
  `e0 | live | e0 | e0`.
- The `E_RENDER_JOB` / `E_RENDER_SEAL` dim-4 gap now names only the
  live proofs, not the code. Named follow-up (not silent): one 150 s
  server + `SPAWN=1 COMBAT=1` wired-draw leg per sibling (same bar as
  the lead live — `drew instances=` with buckets, census, exact-2.0
  + exact-3.0, pure-union saves, zero `E_*`). CLOSED 2026-09-12 below
  (1710 zero live fixes, 1165 two, 1201 one — all in the forge hook,
  the pure plan untouched).

## Addendum — render plan adapter dispatch live, siblings 1710/1165/1201 (2026-09-12)

`PORT_QUEUE` row `Render plan adapter` flips to
`live | live | live | live` (0 `TODO`, 0 `e0` remaining on the row).
Same bar as the lead live per sibling (150 s server + launcher-free
headless direct-client `SPAWN=1 COMBAT=1` run, exit 0):

- 1710 `4e25e2a`, zero live fixes (green first try, host OpenJDK
  1.8.0_502) : server bind clean, world == pure union 1922 (ids
  1,165), zero `E_*` ; direct-client
  `NUMERIC_IDS=example1:my_ore=165 SPAWN=1 COMBAT=1` — `ready
  mesh=72 verts stride=8 program=3` then `drew instances=1 mesh=72
  verts buckets=1` through the seal (GL accepted, `E_GL_DRAW`
  silent), census 2→8, hp 20.0 + 30.0, exact-2.0 at 500→501 then
  exact-3.0 at 600→601 (elapsed 1 each, ambient-damaged brute
  baseline — drop stays exact), kill 1000 → carrier 999 → gem 1001
  (elapsed 1) with same-tick replacement, save pure union 1274,
  zero `E_*` (benign Forge-version-check-offline `Caused by` +
  missing gem-icon texture errors, same as every 1710 proof).
- 1165 `6c248e7` + `01470b6`, two live fixes (both in
  `forge/.../InstancedMeshRenderer.java` only, from-log diagnosis) :
  server bind clean, world == pure union 1922 (native names), zero
  `E_*` ; direct-client `SPAWN=1 COMBAT=1` — `ready mesh=72 verts
  stride=8 program=12` then `drew instances=1 mesh=72 verts
  buckets=1`, census 2→8, hp 20.0 + 30.0, exact-2.0 then exact-3.0
  (elapsed 1 each), kill 1000 → carrier 1000 → gem 1001 (elapsed 1)
  with same-tick replacement, save pure union 1274, zero `E_*` /
  `Caused by`. Fix 1: `flip()` → `rewind()` after Mojang
  `Matrix4f.write` — the SRG `func_195879_b` is absolute-put
  (javap-proven on the pinned bytes), so `flip()` collapsed the
  limit to the unmoved position (first draw died
  `IndexOutOfBoundsException`). Fix 2: join-transient guard — during
  the client-world join `RenderWorldLast` fires with a NaN event
  projection (vanilla draws garbage those frames too), so a
  non-finite product skips the frame BEFORE the seal (never
  planned, never uploaded), loudly on first sight and every 600th,
  refusing `E_RENDER_FRUSTUM:degenerate` past 3600 consecutive bad
  frames (a full minute — persistence is a wiring bug, never a
  transient).
- 1201 `ac31b4c` + `565be27`, one live fix (same guard shape,
  `forge/.../InstancedMeshRenderer.java` only, docker D3_OFFLINE
  warm cache) : server bind clean, world == pure union 1922, zero
  `E_*` ; direct-client `SPAWN=1 COMBAT=1` — `ready mesh=72 verts
  stride=8 program=15` then `drew instances=1 mesh=72 verts
  buckets=1`, census 2→8, hp 20.0 + 30.0, exact-2.0 then exact-3.0
  (elapsed 1 each), kill 1000 → carrier 1000 → gem 1001 (elapsed 1)
  with same-tick replacement, save pure union 1274, zero `E_*`
  (single benign vanilla-flite `Caused by`, same as every 1201
  proof). No buffer fix here (JOML `get()` needs no flip — probed) ;
  the first planned frame refused `E_RENDER_FRUSTUM:degenerate
  <left>` on the identical join transient, hence the guard.
- Parity note (dim 4, declared here, gate green) : the guard's
  `E_RENDER_FRUSTUM:degenerate` refusal lives in the 1165/1201 forge
  hooks only (1 local code each) — it reuses the spike's cited
  thrown set above, no new code family, no new `E_FORGE_*`, no stub
  or narrow-map delta on any sibling. The LWJGL2 fixed-function
  reads (lead + 1710) show no join transient (both green first try),
  so the lead keeps no guard — version-native difference, never
  silent.
- Trouvailles (live ops, no code impact) : `drew` is a per-run
  visibility lottery by design (fixed camera + wandering beasts +
  spawn-band geometry — surface tickets draw, void tickets correctly
  cull, zero-draw runs are correct culling proven offline, not a
  matrix bug) ; 1201 player spawn flails across runs (y=4 hole /
  y=66 surface / y=-60 void — join/chunk-load timing vs flat spawn) ;
  host still has no Java 17 (`/tmp/jdk17` re-extract, never
  committed). No open item remaining on the row.
