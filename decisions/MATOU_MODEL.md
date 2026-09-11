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
  `E_MODEL_CUBE:null/shape/origin/size/uv/nan`,
  `E_MODEL_PLACE:nan`, `E_MODEL_GEO:null/unreadable/no-head`.
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

## Addendum — consumer tranche, bridge-1122 e0 (2026-09-11)

`bridge-1122` `3fe9c6c` wires the bake into the two thin forge
call-sites, E0 (stages 1-2 green, live proof TODO):

- `MatouModel.placedBoxes(x, y, z)` (spi `e52c0d3`): world-space
  placement at the entity origin, the single translation every bridge
  applies instead of copying the offset loop per version. Rejects NaN
  origins (`E_MODEL_PLACE:nan`); the offset applies after the px-to-block
  narrowing (blocks + blocks, never px + blocks).
- `fr.iamacat.bridge.model.BeastModel` (bridge `java/src`, zero MC):
  loads `config/matoubridge/my_beast.geo.json` once (lazy singleton),
  serves the cached baked mesh and `boxesAt` placements. Refuses a null
  path (`E_MODEL_GEO:null`), an unreadable file
  (`E_MODEL_GEO:unreadable`) and a model without the weakspot bone
  (`E_MODEL_GEO:no-head` — the beast-local `WEAKSPOTS` table names
  `head` at 2x until content-driven weakspots land). No `E_FORGE_*`
  code added, no new `forge/src` file: parity file-set and error
  catalog hold untouched.
- `MatouEntity implements Hittable`: `hitBoxes()` rides the entity
  origin (feet), `hitWeakspots()` serves the beast table. No combat
  hook reads them yet.
- `InstancedMeshRenderer`: the static VBO is the SPI bake
  (`vertexCount = mesh.length / VERTEX_STRIDE`, stride likewise
  derived); the hardcoded `BOX_VERTICES` is deleted, single derivation
  point restored. A missing or broken model refuses in `initGl`,
  loudly, before the first frame.
- Asset: `bridge-1122/tools/live/my_beast.geo.json` (the 2-bone beast
  proven by the SPI goldens) ships to `dist/` (SHA-pinned) and to
  `$SERV/config/matoubridge/` beside packs.cfg; the hub client script
  stages it keep-or-copy like packs.cfg. Operator-replaceable, harness
  never clobbers a hand-tuned copy it did not write.
- Gate `ModelWireCheck` (bridge `java/test`, wired in
  `bridge-1122/tools/check.sh`): shipped asset loads/bakes/resolves
  end to end pure (bones body+head tripwire the weakspot table),
  temp-file roundtrip, refusal battery (`E_MODEL_GEO:*` plus a
  non-geometry file proving `E_MODEL_JSON:syntax` propagation).
- `PORT_QUEUE` row `Beast model mesh+hitboxes`: `TODO | e0 | TODO |
  TODO`. Live proof (client visual + server no-regression) rides the
  next live tranche, never silently.

## Addendum — server no-regression live half, bridge-1122 (2026-09-11)

`bridge-1122` `393c020` proves the server half live, E0 stages 1-3
green (`LIVE=1`, host OpenJDK 1.8.0_502):

- 150 s Forge 2860 run, bind clean (no `NoSuchMethodError` /
  `NoSuchFieldError`, no `E_*` refusal, mod loaded), world == pure
  union (1922 cells, ids 1,253 — the exact T4 union, zero content
  regression from the model wiring).
- `my_beast.geo.json` deployed beside packs.cfg byte-identical to the
  shipped asset (`sha256 6577bfaf...eefbb`), zero `E_MODEL_*` on both
  server logs (the model path is client-only; the server ignores it
  cleanly). Step 6 refusal grep now trips on `E_MODEL` too, so any
  future server-side model refusal fails loudly instead of passing
  silently.
- `PORT_QUEUE` stays `TODO | e0 | TODO | TODO`: the client-visual half
  (Prism/XVFB proof that the baked VBO actually draws) is still TODO.
  Precedent: the GL row stayed `e0` after its server-only proof for
  the same reason — `e0` means live proof incomplete, never
  server-proven.

## Addendum — client-visual proof protocol, bridge-1122 (2026-09-11,
corrected same day)

The `e0` flips to `live` on a launcher-free headless run
(`hub/tools/run-client-direct.sh --bridge ../bridge-1122` after
`AUTOPLAY=1 SPAWN=1` staging, `SPAWN=1` at play — same GL, same mods,
same world as Prism, no launcher), never on code alone. Correction:
this protocol first prescribed the Prism path (`run-client.sh XVFB=1`)
and the tranche re-measured why `DIRECT_CLIENT_PROOF.md` refuses it
for automation — the isolated Prism root stalls on its first-run
wizard (fixed reproducibly by seeding `Language`), then on the
missing `accounts.json` (Critical, then idle black screen with
`--launch` ignored). Prism stays manual-dev; the proof rides the
direct path the org already owns.

- `SPAWN=1` loads bridge-landed beasts into the client's
  `loadedEntityList` — the exact list the renderer packs — so at least
  one frame draws `count >= 1` (a never-loaded beast proves no pixels).
- The instance log shows `[MatouRenderer] drew instances=<n>` with
  `n >= 1`, and zero `E_*` (the `E_GL_DRAW:failed` tripwire in
  `GL_INSTANCING_ADAPTER.md` fails a GL-rejected draw loudly instead of
  logging a lying `drew`).
- `verify-client-save.sh` still replays world == pure union (the
  renderer is client-only; a content drift fails there, never here).

Pixel proof (screenshot with the beast in frame) is refused: autoplay
never aims the camera, so framing would be luck. The chain closes
without it: `ModelWireCheck` proves bake == shipped asset,
`[MatouRenderer] ready` proves the VBO upload is that bake
(`mesh=<N> verts`), `drew` proves GL accepted the instanced draw.

## Addendum — client-visual proof live, bridge-1122 (2026-09-11)

`bridge-1122` `34ed5b6`..`6988515` proves the visual half live
(`LIVE=1` server re-proof + launcher-free headless client, host
OpenJDK 1.8.0_502 for the game):

- Server re-proof green with the 42-line map (bind clean, ticks
  clean, world == pure union 1922 cells, ids 1,253 — same T4 union,
  zero content regression from the renderer/mapping tranche).
- Client (`run-client-direct.sh`, `SPAWN=1`, Xvfb/llvmpipe, exit 0):
  `[MatouRenderer] ready mesh=72 verts stride=8` (2 cubes x 36 — the
  SPI bake, never the placeholder box), `[MatouRenderer] drew
  instances=4 mesh=72 verts` (GL accepted the instanced draw of all 4
  census beasts; the `E_GL_DRAW:failed` tripwire stayed silent, i.e.
  green), zero `E_*` and zero linkage errors in `game.log`, spawn
  proof alongside (census 1→4, hp 20.0, kill + carrier).
- `verify-client-save.sh` replays world == pure union (1274 cells,
  stone id 1) on the client save — the renderer draws, it never
  places.
- Observed nonfatal: `example1:models/item/my_gem.json`
  `FileNotFoundException`/`MissingVariantException` (the registered
  gem ships no client item model yet — item-model JSON is its own
  tranche; Forge substitutes the missing model, exit stays 0).
- Tranche findings (same silent class as last tranche's `E_MODEL`
  grep): the autoplay companion had not compiled since the item
  tranche (missing `Item` import + duplicate `Minecraft` stub — no
  gate built it; `check.sh` now compiles it as `ok
  (autoplay-compile)`, stubs merged single), and the live narrow map
  covered server refs only (first `RenderWorldLastEvent` crashed the
  client on unmapped `getMinecraft`; the map is 42 lines now, and
  step 3b scans the built MCP jar's constant pool against it —
  `E_MAP_COVER` fails the next gap at build time, never live).
- `PORT_QUEUE` row `Beast model mesh+hitboxes` flips to `TODO |
  live | TODO | TODO`.

## Addendum — port live, bridge-1710 (2026-09-11)

`bridge-1710` `f3ef9f6` (E0) + `41c3c33` (descriptor fix) ports the
consumer + renderer version-native, proven live the same day
(`LIVE=1` server + launcher-free headless client, host OpenJDK
1.8.0_502 for the game):

- Server green first try with the 8 renderer pins (bind clean, ticks
  clean, world == pure union 1922 cells, ids 1,165 — same T4 union,
  zero content regression). `my_beast.geo.json` deployed byte-identical
  (`6577bfaf...`), zero `E_MODEL_*` server-side.
- Client (`run-client-direct.sh`, `SPAWN=1`, Xvfb/llvmpipe, exit 0):
  `[MatouRenderer] ready mesh=72 verts stride=8 program=3` (the SPI
  bake), `[MatouRenderer] drew instances=4 mesh=72 verts` (GL accepted,
  `E_GL_DRAW` silent), zero `E_*` / linkage errors, spawn proof
  alongside (census 1→4, hp 20.0, kill + carrier).
- `verify-client-save.sh` replays world == pure union (1274 cells,
  stone id 1) — same stone-proof default as the 1122 visual run.
- 1614-native shapes (srg-mcp.srg-derived, full-map era — no narrow map
  needed, the complete SRG already covers client classes; Forge members
  stay universal-pinned): `theWorld` field (`field_71441_e`,
  WorldClient-typed), `renderViewEntity` FIELD (`field_71451_h` — the
  1122 getter does not exist here), event `partialTicks` FIELD (same).
  Single-Minecraft stub merged into `tools/live/stub` (`autoplay/stub`
  deleted — same duplicate-class trouvaille as 1122).
- Trouvaille (descriptor-truth class, one 600 s timeout): the stub
  typed `renderViewEntity` as `Entity`, but the 1614 runtime field
  (`bao.i`) is `sv` = `EntityLivingBase` (javap on the pinned vanilla
  primary + `CL` row of the runtime `deobfuscation_data-1.7.10.lzma` —
  SRG `field_71451_h` was right, the DESCRIPTOR was recalled). The
  renderer narrows to `Entity` by cast (all reads are Entity-declared,
  Reobf hits directly). Corroborated in passing: `bao/f` = WorldClient
  (`theWorld`), `bao/g` = RenderGlobal (`field_71438_f`), `bao/h` =
  player (`field_71439_g` — the exact 1122 trap, not repeated).
- `PORT_QUEUE` row `Beast model mesh+hitboxes` flips to `live |
  live | TODO | TODO`.

## What remains (re-opens as spec, not silently)

1. Bridge consumer: replace `BOX_VERTICES` with `bakeMesh` output and
   feed `boneBoxes` to the entity `Hittable` (lead bridge first, then
   PORT_QUEUE ports).
2. Per-face `uv` + texture sampling in the instancing shader (V2).
3. Bind-pose rotation/pivot bake and animation tables (later tranche).
