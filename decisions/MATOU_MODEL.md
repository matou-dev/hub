---
type: spec
status: active
maturity: standard
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
- `ModelBone.java`: name, optional parent, bind-pose pivot (px),
  bind-pose Euler rotation (degrees, x-then-y-then-z — baked around the
  pivot since the rotation tranche), default inflate (px) for cubes
  that carry none, cubes in file order.
- `MatouModel.java`: identifier, texture grid, bones. Single derivation
  point: `bakeMesh()` feeds the renderer VBO, `boneBoxes()` feeds
  `HitTester`.
- `MatouModelParser.java`: first entry of `minecraft:geometry` wins;
  multi-geometry files split before import. Bone parents validate
  against the model bone set (forward refs allowed). Per-face `uv`,
  `rotation` and `mirror` beyond acceptance are NOT baked (see below).
- Frozen Bedrock subset: `format_version` string (value recorded,
  ignored), `description.identifier` (required), `texture_width/height`
  (integral, 1..4096), bones (`name` unique non-blank, acyclic
  `parent` optional, `pivot` optional [x,y,z] default origin,
  `rotation` optional [x,y,z] degrees default unrotated, `inflate`
  optional default 0 funding bare cubes, `poly_mesh`/`texture_meshes`
  refused — deprecated/experimental, never a silent drop, other
  non-geometric keys ignored), cubes (`origin`/`size` required [x,y,z],
  `uv` optional [u,v] default [0,0] or per-face, `inflate` optional
  defaulting to the bone value, `rotation` optional default unrotated,
  `pivot` optional defaulting to the box center, `mirror` accepted and
  ignored).
- Bake rules: pixels in, block units out (`PX_PER_BLOCK = 16`); one
  `BoneBox` per non-empty bone (axis-aligned union of the bone's
  rotated cube corners — conservative over the rotated shape,
  entity-local, bind pose); `bakeMesh` emits 36 interleaved vertices
  per cube (`VERTEX_STRIDE = 8`: pos3, uv2, normal3 — the exact layout
  `InstancedMeshRenderer` uploads); each cube rotates around its own
  pivot first, then around its bone pivot, then around every ancestor
  pivot to the root (Euler degrees x-then-y-then-z extrinsic,
  `R = Rz * Ry * Rx`, right-handed); normals rotate translation-free
  and renormalize; faces keep the live-proven corner order (outward
  CCW — the winding comparateur proves it over rotated meshes too);
  UVs never move under rotation (box-anchored V1 path and per-face V2
  rects alike); a zero rotation skips bit-for-bit (unrotated models
  bake byte-identical to the pre-rotation code — the compat
  comparateur pins it).
- Thrown set (SPI-owned, cited here so no bridge redefines them):
  `E_MODEL_JSON:empty/syntax/type`, `E_MODEL_VERSION:missing`,
  `E_MODEL_GEOMETRY:missing/shape`, `E_MODEL_IDENTIFIER:missing`,
  `E_MODEL_TEXTURE:shape`, `E_MODEL_BONE:empty/shape/duplicate/parent/pivot/rotation/inflate`,
  `E_MODEL_CUBE:null/shape/origin/size/uv/nan/rotation/pivot`,
  `E_MODEL_FACE:shape/uv/size/rotation`, `E_MODEL_TEX:dims`,
  `E_MODEL_PLACE:nan`, `E_MODEL_GEO:null/unreadable/no-head`.
- Gate `ModelCheck`
  (`spi/java/test/fr/iamacat/spi/model/ModelCheck.java`, wired in
  `spi/tools/check.sh`): parse goldens (2-bone beast, empty model,
  defaulted cube), bake fidelity (vertex count, first-vertex
  pos/uv/normal, head UV anchor), winding comparateur (cross-product
  normal of all 24 triangles dots the declared normal — proves
  outward CCW, i.e. no culled beast), `boneBoxes` union + inflate
  goldens with `HitTester` bone resolution (front ray -> body, high
  ray -> head), rotation battery (explicit-zero byte-identity
  comparateur, bone-yaw box/normal goldens, parent-orbit hierarchy,
  cube-pitch beam, bone-inflate default, winding over rotated meshes),
  refusals battery over the whole `E_MODEL_*` catalog.

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

## Addendum — port live, bridge-1165 (2026-09-11)

`bridge-1165` `628f849` (E0) + `c6e15b7` (live fixes) ports the
consumer + renderer version-native, proven live the same day (`LIVE=1`
server + launcher-free headless client, host OpenJDK 1.8.0_502 for the
game):

- Server green with the 48-line map (bind clean, ticks clean, world ==
  pure union 1922 cells, my_ore + stone — same T4 union, zero content
  regression). `my_beast.geo.json` deployed byte-identical
  (`6577bfaf...`), zero `E_MODEL_*` server-side. `E_MAP_COVER` scans
  the built jar (ported from 1122, extended to `com/mojang/` owners,
  SRG-spelled refs passing through by construction, one ALLOW row for
  the MCP-named `EntityClassification/CREATURE` enum constant every
  server run executes).
- Client (`run-client-direct.sh`, `SPAWN=1`, Xvfb/llvmpipe, exit 0):
  `[MatouRenderer] ready mesh=72 verts stride=8 program=12` (the SPI
  bake on the first LWJGL3 driver), `[MatouRenderer] drew instances=4
  mesh=72 verts` (GL accepted, `E_GL_DRAW` silent), zero `E_*` /
  linkage errors, spawn proof alongside (census 1→4, hp 20.0).
- `verify-client-save.sh` replays world == pure union (1274 cells,
  stone) — same stone-proof default as the 1122/1710 visual runs.
- 1165-native shapes (snapshot+tsrg+javap-derived, narrow-map era with
  a client-jar leg): `getInstance` (the 1122 `getMinecraft` does not
  exist here), `world` field ClientWorld-typed (the 1122 WorldClient
  trap in 1.16.5 spelling), `getRenderViewEntity` METHOD
  Entity-typed (the 1710 EntityLivingBase trap is absent here — the
  same-sounding `func_216773_g` lives on ActiveRenderInfo),
  iteration rides `ClientWorld.getAllEntities` (the 1.12
  `loadedEntityList` field is gone; same-sounding `func_217369_A` is
  players-only), interpolation rides `prevPos + (getPos - prevPos) *
  pt`, matrices ride the event MatrixStack top + projection via
  `Matrix4f.write` (no `glGetFloat` on blaze3d). Single-Minecraft stub
  merged into `tools/live/stub` (`autoplay/stub` deleted — same
  duplicate-class trouvaille as 1122/1710).
- Trouvailles (two timeouts, crash-fast killed both in seconds once
  the markers landed): the stub strip covered `net/` (+`org/` client
  side) but not `com/` — the fake `MatrixStack` shipped in the DEV
  bridge jar and the loading overlay died deterministically
  (`AbstractGui.fill` NPE; fixed both strips, the hub one in
  `run-client.sh`); the `*C` stub copied the LWJGL2 name
  `glUniformMatrix4`, but LWJGL 3.2.2 only declares
  `glUniformMatrix4fv` (javap on the provisioned game libraries — the
  full `*C` surface verified the same way, all other names hold).
  Same class as trouvaille #3 (recalled descriptor), LWJGL-side.
- `PORT_QUEUE` row `Beast model mesh+hitboxes` flips to `live |
  live | live | TODO`.

## Addendum — port live, bridge-1201 (2026-09-11)

`bridge-1201` `8d7b0d8` (E0) ports the consumer + renderer
version-native, proven live the same week with zero live fixes
(`run-client-direct.sh`, `SPAWN=1`, Xvfb, exit 0, host Temurin
17.0.20 for the game — the 180 s probe timed out on budget only,
game alive rendering; the full 600 s run exited 0 by itself):

- Server green with the 48-line narrow map on the thin wrapper +
  shared derive lib (bind clean, ticks clean, world == pure union
  1922 cells, `my_ore` + `my_gem` registered — recorded in hub
  `decisions/LIVE_SHELL_COMMON.md`, never duplicated here).
- Client: `[MatouRenderer] ready mesh=72 verts stride=8
  program=15` (the SPI bake on the second LWJGL3 driver),
  `[MatouRenderer] drew instances=4 mesh=72 verts` (GL accepted,
  `E_GL_DRAW` silent), zero `E_*` / linkage errors, spawn proof
  alongside (census 1→4 at worldTicks 2..5, kill at 1000, gem drop
  at 1001 elapsed 1, immediate).
- `verify-client-save.sh` replays world == pure union (1274 cells,
  stone) — same stone-proof default as the sibling visual runs.
- 1201-native shapes (triple-lock derived, server+client txt plus
  dual-javap): `getInstance` static, `level` field
  ClientLevel-typed, `getCameraEntity` Entity-typed, matrices ride
  `PoseStack.last/pose` plus the event projection matrix (JOML
  direct, no Mojang-math write), iteration names no ClientLevel
  member (polls the already-mapped
  `EntityGetter.getEntitiesOfClass`), frame event is
  `RenderLevelStageEvent` gated on `AFTER_ENTITIES` (no
  `RenderWorldLastEvent` here), join rides official
  `--quickPlaySingleplayer` (no programmatic join surface), game jar
  is the installer client-extra (never the vanilla primary —
  split-package `ResolutionException`, measured).
- Trouvaille (vanilla noise, never asserted): Mojang `GlDebug`
  `GL_INVALID_OPERATION in glDrawElements` spam under Xvfb/swrast
  starting ~50 s after our draw, at the tick-999/1000 kill+drop
  legs (the dropped-gem item entity begins rendering) — our draw is
  drain-then-judged per frame with VAO/program/buffer unbound
  after, and `E_GL_DRAW` stays silent throughout ; same proof
  standard as the siblings (no verdict ever asserted on vanilla
  `GlDebug` lines). Vanilla flite narrator `UnsatisfiedLinkError`
  at boot is non-fatal (game continues, narrator dead headless).
- `PORT_QUEUE` row `Beast model mesh+hitboxes` flips to `live |
  live | live | live` (0 `e0` remaining).

## What remains (re-opens as spec, not silently)

1. Bridge consumer: replace `BOX_VERTICES` with `bakeMesh` output and
   feed `boneBoxes` to the entity `Hittable` — DONE live x4 (1122
   `34ed5b6`..`6988515`, 1710 `f3ef9f6` + `41c3c33`, 1165 `628f849` +
   `c6e15b7`, 1201 `8d7b0d8` ; `PORT_QUEUE` `live | live | live |
   live`, closed by the standard promotion).
2. Per-face `uv` + texture sampling in the instancing shader (V2).
   DONE live x4 2026-09-12 (lead E0 + lead live, dispatch E0 + dispatch
   live addenda below, `PORT_QUEUE` `live | live | live | live` — row
   closed).
3. Bind-pose rotation/pivot bake — DONE E0 2026-09-12 (SPI-only,
   rotation addendum below: bone + cube Euler, hierarchy, conservative
   boxes, unrotated byte-identity, zero bridge change), lead live
   2026-09-12 (rotation live-proof addendum below: rotated asset draws
   + hits through the seal on 1122, `PORT_QUEUE`
   `TODO | live | TODO | TODO` — three dispatch ports TODO).
4. Animation tables (`animations` keyframes, controllers, MOLANG) —
   later tranche, own spec (needs a content expression subset + a
   tick-time pose evaluation — never smuggled into the bind-pose bake).

## Addendum — beast texture V2 E0, lead bridge-1122 (2026-09-12)

Lands the V2 the frozen subset promised: per-face unwrap in the SPI
bake plus a sampled texture on the lead renderer. Stages 1-2 green on
the lead, live proof TODO — same bar as every lead E0.

- Frozen-subset extension (the box `uv` array is untouched): a cube
  `uv` may instead be an object mapping face names (`north`/`south`/
  `east`/`west`/`up`/`down`, bedrock.dev + Microsoft Learn geometry
  schema) to `{uv [u, v] required, uv_size [w, h] optional defaulting
  to the face box dims (south/north `(sx,sy)`, up/down `(sx,sz)`,
  east/west `(sz,sy)`), uv_rotation optional default 0,
  material_instance accepted and ignored — no bake effect}. A non-zero
  `uv_rotation` refuses (`E_MODEL_FACE:rotation` — never a silent
  unrotated bake) ; unknown face names or face keys refuse
  (`E_MODEL_FACE:shape` — never a silent drop) ; negative origins,
  non-positive sizes and grid overhangs refuse (`E_MODEL_FACE:uv` /
  `E_MODEL_FACE:size` — the sampler clamps, an overhang would smear
  silently). An omitted face bakes nothing (vanilla parity).
- Bake rules (spi `806411d`): `ModelCube` carries `faceUv` (null = box
  mode, the old constructor delegates untouched) ; `emitCube` reads
  each present face from its own rect with the Bedrock upper-left
  convention (v = 0 at the texture top, matching the top-row-first
  upload the bridges perform — never flipped): five faces share the
  corner pattern a→`(u0,v0+h)` b→`(u0+w,v0+h)` c→`(u0+w,v0)`
  d→`(u0,v0)`, down anchors `(u0,v0)` at b per bedrock.dev. Box-anchor
  cubes bake byte-identical V1 (the existing `ModelCheck` goldens pass
  unmodified — the compat comparateur) ; `bakeMesh` sizes dynamically
  (a per-face cube emits 6 vertices per present face only).
- Thrown-set addition (SPI-owned, cited here so no bridge redefines
  it): `E_MODEL_FACE:shape/uv/size/rotation`.
- Gate `ModelCheck` gains the per-face battery (5-face fixture with an
  omitted face, `uv_size` default, top-left goldens per face, the
  winding comparateur over both meshes, the full refusal battery).
- Bridge harness, lead only (bridge-1122 `00f9ce4`): `BeastTexture`
  holder (`java/src`, zero MC — loads `config/matoubridge/my_beast.png`
  via ImageIO, RGBA top-row-first with no flip, dims must equal the
  model grid or `E_MODEL_TEX:dims`) ; renderer V2 shaders (`v_uv`
  varying — `a_uv` was bound since V1, never read — `sampler2D u_tex`
  on unit 0, `col = texture * tint * diffuse`, no tint-only fallback
  switch) ; upload once at `initGl` (NEAREST + CLAMP_TO_EDGE, no
  mipmaps — NPOT-safe), the `ready` line gains `texture=64x64` (the
  live leg greps it — an untextured draw cannot pass silently) ;
  per-bucket bind beside the repack (one shared texture today,
  per-mob textures plug the same call — named follow-up). The bucket
  key stays `tint` (single mesh + texture — `InstanceFormat`/`Rec`
  untouched). A missing or broken texture refuses at `initGl`,
  loudly, before the first frame.
- Asset: `bridge-1122/tools/live/my_beast.png` (64x64 RGBA, sha256
  `851079978ed0d8cf479f91a06c1d34065738a504035e0ba1fa4c30195d69557f`,
  stdlib-generated: body rect `x[0,16) y[0,16)` green, head rect
  `x[32,41) y[0,9)` orange over magenta backfill — unmapped texels
  scream). `run-live.sh` deploys it (dist + `SHA256SUMS` + server
  config) ; the hub client script keeps-or-stages it like the geo.
- Gate `ModelWireCheck` gains the texture battery (shipped
  dims/texels/order goldens, upload-buffer size, the `E_MODEL_TEX`
  refusal battery incl. a dims-mismatch temp png).
- Siblings mechanical conformance only (1710 `f889b62`, 1165
  `e327c03`, 1201 `e826c45` to `806411d` — backend texture methods in
  era-native spelling plus stub rows plus the pin ; no
  renderer/holder/png): their cells stay TODO with this addendum as
  the dispatch-port rationale, never silent. The sibling texture
  methods link for real at dispatch live (stub-shaped until then —
  declared here).
- `PORT_QUEUE` new row `Beast texture V2, per-face uv + sampling`
  (`BRIDGE_PARITY.md`): `TODO | e0 | TODO | TODO`.
- Parity gap (dim 4, declared here): `E_MODEL_TEX` (holder refusals)
  exists on 1122 only until the dispatch ports land it on the
  siblings ; no new `E_FORGE_*`, no new `forge/src` file, no new SPI
  error-code family beyond the cited `E_MODEL_FACE`.
- Named follow-ups blocking live (not silent): 150 s server re-proof
  (the renderer is client-only — regression only) + headless
  direct-client `SPAWN=1 COMBAT=1` legs proving the textured draw
  (`texture=64x64` in the `ready` line, `drew instances=` with
  buckets, census 2→8, exact-2.0 + exact-3.0 intact, saves pure
  union, zero `E_*`).

## Addendum — beast texture V2 live, lead bridge-1122 (2026-09-12)

`bridge-1122` `00f9ce4` (E0) proves the textured draw live on Forge
2860 (150 s server + launcher-free headless direct-client
`NUMERIC_IDS=example1:my_ore=253 SPAWN=1 COMBAT=1` run,
Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — renderer client-only, regression leg only,
  zero `E_*`).
- Client: `ready mesh=72 verts stride=8 texture=64x64 program=12`
  (the V2 upload, `BeastTexture` 64x64 RGBA top-row-first) then
  `drew instances=1 mesh=72 verts buckets=1` — the first sampled
  draw through the seal (one mob-addressed bucket over the shared
  mesh, GL accepted, `E_GL_DRAW` silent; a single visible beast on
  the first drawn frame, same wander-plus-fixed-camera sampling as
  the render-plan live proof — later fuller frames stay quiet by
  design, pixel proof stays refused); census 2→8 balanced
  (`beast=brute`, cap 8) at worldTicks 2..5, `spawn hp <my_beast
  20.0>` + `spawn hp <my_brute 30.0>`, exact-2.0 at 500→501 then
  exact-3.0 at 600→601 (elapsed 1 each, full-health baselines 20.0
  → 18.0 and 30.0 → 27.0 this run — ambient dim-0 falls at ticks
  49/296/308/324 paid per-mob through loot with replacements, the
  struck pair untouched), spawn kill at 1000 → gem polled at 1001
  (elapsed 1) ; `verify-client-save.sh` world == pure union (1274
  cells, `1,253` via `NUMERIC_IDS`) ; zero `E_*` / linkage (the
  only `Caused by` lines are the known benign gem-model bakes —
  missing `models/item/my_gem.json` + `my_brute_gem.json` +
  `blockstates/my_ore.json`, same signature as every 1122 proof
  since item registration).
- Trouvaille (convention lock, no code impact): V1 bound `a_uv`
  but never read it, mapping v = 0 at the face bottom with no
  consequence while UVs were ignored — V2 per-face follows Bedrock
  v = 0 at the texture top end to end (bake, top-row-first upload,
  no-flip sampler). The two conventions must never be mixed when
  reading old goldens against the new battery.
- `PORT_QUEUE` row `Beast texture V2` flips to
  `TODO | live | TODO | TODO` (lead live, three dispatch ports TODO —
  the `E_MODEL_TEX` dim-4 gap names them).

## Addendum — beast texture V2 dispatch E0, siblings 1710/1165/1201 (2026-09-12)

Stages 1-2 green on all three siblings, live proof TODO — same bar
as the lead E0. The shared pieces ride verbatim (byte-identical
`BeastTexture` holder — `BeastModel` is identical on all four
bridges — byte-identical `my_beast.png`
`851079978ed0d8cf…`, same `testShippedTexture` battery, same GLSL) ;
only the placement is version-native:

- 1710 `79fdf1d` (LWJGL2/cup): V2 hunks at the 1614 anchors
  (`theWorld` / `(Entity) renderViewEntity` / `partialTicks`
  field untouched), `GL11` backend spelling from the conformance
  tranche.
- 1165 `d8543d5` (LWJGL3/blaze3d): V2 hunks at the 36.2.42 anchors
  (`getInstance` / `MatrixStack` event / `getAllEntities` /
  `Matrix4f.write` feed untouched), `GL11C` backend spelling ;
  the 5 extra content-weakspot battery lines kept.
- 1201 `c455a3b` (LWJGL3/JOML): V2 hunks at the 47.2.0 anchors
  (`AFTER_ENTITIES` gate / `EntityGetter` / JOML feed /
  join-transient guard untouched), `GL11C` backend spelling.

Zero new MC surface on all three (no stub or narrow-map delta —
every member read was already pinned ; the added refs are
bridge/SPI/JDK only — the renderer additions speak the `GlBackend`
interface alone). The `E_MODEL_TEX` dim-4 gap is retired
(`BeastTexture` now rides all four bridges — hub parity gap
`1122 local-codes=5` reads 0) ; the remaining gap names only the
three live proofs. Named follow-up (not silent): one 150 s server +
`SPAWN=1 COMBAT=1` textured-draw leg per sibling (same bar as the
lead live — `texture=64x64` in the `ready` line, `drew instances=`
with buckets, census, exact-2.0 + exact-3.0, pure-union saves,
zero `E_*`).
- `PORT_QUEUE` row `Beast texture V2` (`BRIDGE_PARITY.md`):
  `e0 | live | e0 | e0`.

## Addendum — beast texture V2 dispatch live, siblings 1710/1165/1201 (2026-09-12)

`PORT_QUEUE` row `Beast texture V2` flips to
`live | live | live | live` (0 `TODO`, 0 `e0` remaining on the row —
the V2 row is closed). Same bar as the lead live per sibling (150 s
server + launcher-free headless direct-client `SPAWN=1 COMBAT=1` run,
exit 0, `texture=64x64` in the `ready` line, `drew instances=` with
buckets, census, exact-2.0 + exact-3.0, pure-union saves, zero `E_*`):

- 1710 `79fdf1d` + `609b8ca`, two live fixes (forge hook +
  DEV-only autoplay, SPI untouched, host OpenJDK 1.8.0_502) :
  server bind clean, world == pure union 1922 (ids 1,165), zero
  `E_*` (benign Forge-version-check-offline `Caused by` only, same
  as every 1710 proof) ; direct-client
  `NUMERIC_IDS=example1:my_ore=165 SPAWN=1 COMBAT=1` — `ready
  mesh=72 verts stride=8 texture=64x64 program=3` then `drew
  instances=3 mesh=72 verts buckets=1` through the seal (GL
  accepted, `E_GL_DRAW` silent), census 2→8, hp 20.0 + 30.0,
  exact-2.0 at 500→501 (drop=2.0 hp=18.0) then exact-3.0 at
  600→601 (drop=3.0 hp=27.0, elapsed 1 each), kill 1000 → gem
  1001 (elapsed 1), save pure union 1274 (1,165), zero `E_*`.
  Fix 1: matrix capture at `RenderWorldEvent.Pre` — by `Last`
  time the 1614 modelview is dead (vestigial rotate, ~zero
  translation — everything culled, measured live), so the chunk
  pass captures both matrices while the camera transform is
  still active and the `Last` draw consumes the stored pair
  (same pure chain downstream, only the read point moves ; new
  shape-only stub + pin row, no new member surface). Fix 2
  (autoplay DEV-only): the combat strike follows the vanilla
  `/tp` bytecode (`setPlayerLocation` moves the server player
  AND delivers the S08 with eye height — a bare
  `setPositionAndRotation` never self-syncs on 1614, verified
  by javap — so the client camera rides to the struck head).
- 1165 `d8543d5` + `571b987`, two live fixes (forge hook +
  DEV-only autoplay, SPI untouched, narrow map stays 59) :
  server bind clean, world == pure union 1922 (native names),
  zero `E_*` ; direct-client `SPAWN=1 COMBAT=1` — `ready
  mesh=72 verts stride=8 texture=64x64 program=12` then `drew
  instances=1 mesh=72 verts buckets=1` (GL accepted, `E_GL_DRAW`
  silent), census 2→8 (4+4), hp 20.0 + 30.0, exact-2.0 at
  500→501 (drop=2.0 hp=18.0) then exact-3.0 at 600→601
  (drop=3.0 hp=23.0, ambient-damaged 26.0 baseline — drop
  stays exact, elapsed 1 each), kill 1000 → gem 1001 (elapsed
  1), save pure union 1274, zero `E_*` / `Caused by` / crash.
  Fix 1: camera view rebuilt bridge-side from the interpolated
  eye + render-view yaw/pitch through vanilla's own
  look-vector formula — the event MatrixStack top is a
  leftover rotation (yaw ~180, never the camera, proven by an
  offline replay: 8 recs, buckets=0), so it feeds nothing
  anymore (projection still rides the event ; its rows stay
  pinned but unreferenced until the next row rebalance).
  Fix 2 (autoplay DEV-only): at tick 985 every living beast
  walks onto a presentation pad around the spawn camera (four
  cardinal pads ~7 blocks out — the headless camera never
  moves, server teleports carry no look packet) ; the kill
  leg still takes the first living beast at tick 1000
  wherever it stands.
- 1201 `c455a3b` + `a4092db`, one live fix (DEV-only preseed,
  renderer + SPI untouched, docker D3_OFFLINE warm cache) :
  server bind clean, world == pure union 1922, zero `E_*`
  (`my_ore` + `my_gem` registered) ; direct-client `SPAWN=1
  COMBAT=1` (no `NUMERIC_IDS`, official quick-play join) —
  `ready mesh=72 verts stride=8 texture=64x64 program=15`
  (one known join-transient guard frame) then `drew
  instances=6 mesh=72 verts buckets=1` (GL accepted,
  `E_GL_DRAW` silent), census 2→8, hp 20.0 + 30.0, exact-2.0
  at 500→501 (drop=2.0) then exact-3.0 at 600→601 (drop=3.0,
  elapsed 1 each), kill 1000 → gem 1001 (elapsed 1), save
  pure union 1274 (stone), zero `E_*` (single benign
  vanilla-flite `Caused by`, same as every 1201 proof ; the
  known `GlDebug` post-draw spam stayed absent this run —
  never asserted either way). Fix: preseed `SpawnY` 5 → 66 —
  1.20 stacks the 4 flat layers from the world bottom
  (-64..-61), so the pre-1.18 value dropped the player 66
  blocks in the air and the join search raced floor-vs-wire
  per run (measured: -60 one run, 66 the next, same bytes) ;
  feet 66 stands on the proof cap beside the beast pads,
  inside the renderer box every run.
- Parity note (dim 4, declared here, gate green) : no new
  `E_*` code family on any sibling (1710 local-codes 0, 1165
  1 and 1201 1 — the pre-existing `E_RENDER_FRUSTUM` guard
  reuse), no new `E_FORGE_*`, no stub or narrow-map delta
  beyond the cited 1710 `Pre` pin (class-only, reads no
  member). The `drew` count stays a per-run visibility
  lottery by design (fixed camera + wandering beasts — 3 on
  1710, 1 on 1165, 6 on 1201 — same sampling as the lead's
  single visible beast on its first drawn frame).
- Trouvaille (live ops, no code impact) : the 1710 + 1165
  legs raced port 25565 twice (parallel sibling servers —
  wait + retry, no conflict class) ; 1201 native server
  impossible under the race, hence docker (documented
  `Dockerfile` voie, never committed bytes).

## Addendum — bind-pose rotation bake E0, SPI-only (2026-09-12)

Lands the frozen subset's rotation half: the parser used to drop bone
and cube `rotation` silently (a turned head baked axis-aligned with no
refusal — the silent-default class), and bone `inflate` never funded
bare cubes. Stages green in SPI, zero bridge change, no live re-proof
(pure SPI tranche, declarative precedent).

- Frozen-subset extension: bone `rotation` optional [x,y,z] finite
  degrees defaulting to unrotated (`E_MODEL_BONE:rotation` otherwise);
  bone `inflate` optional finite default 0, funding cubes that carry
  none (`E_MODEL_BONE:inflate` otherwise); cube `rotation` optional
  default unrotated (`E_MODEL_CUBE:rotation`); cube `pivot` optional
  defaulting to the box center (`E_MODEL_CUBE:pivot`); bone
  `poly_mesh`/`texture_meshes` refuse (`E_MODEL_BONE:shape` —
  deprecated/experimental geometry never drops silently); parent
  cycles refuse (`E_MODEL_BONE:parent` — the bake now walks the tree,
  a cycle would orbit forever). `mirror` stays accepted-and-ignored
  (UV-only effect, same as V2 — flipping it is its own tranche, never
  smuggled here).
- Bake rules (`MatouModel`, pure, zero dep): inflate the unrotated
  box, rotate its 8 corners around the cube pivot, then around the
  bone pivot, then around every ancestor pivot to the root (a parented
  bone rides its parent — the Bedrock skeleton). Euler degrees
  x-then-y-then-z extrinsic (`R = Rz * Ry * Rx`, right-handed, per the
  Microsoft schema note). Normals rotate translation-free and
  renormalize; UVs never move. A zero rotation skips bit-for-bit, so
  an unrotated model bakes byte-identical to the pre-rotation code.
- `boneBoxes` unions the rotated corners per bone (axis-aligned,
  conservative — it covers the rotated shape, never less; HitTester
  stays AABB, an exact oriented test is a named follow-up if a
  rotated limb ever proves too generous).
- Gate `ModelCheck` gains the rotation battery: explicit-zero
  float-identity comparateur over mesh + boxes (this is what lets the
  bridges skip re-proof), bone-yaw goldens (2x1x1 slab yawed 90
  about its center stands 1x1x2 — first-vertex pos, +X south normal,
  box bounds, ray hit), hierarchy golden (child cube orbits the
  parent 90-degree yaw — empty parent bakes no box), cube-pitch
  golden (1x2x1 column pitched 90 about its center stands a 1x1x2
  beam), bone-inflate golden, winding comparateur over every rotated
  mesh, refusal battery for the five new codes.
- Bridge impact: none. Bridges consume `bakeMesh` / `boneBoxes` /
  `placedBoxes` opaquely (signatures unchanged) and the shipped
  2-bone beast carries no rotation (bakes byte-identical — the
  compat comparateur above): no re-pin required, no live re-proof,
  no `PORT_QUEUE` cell moves, no new `E_FORGE_*`, no stub or
  narrow-map delta.
- Explicit non-goal: animation tables (`animations`, keyframes,
  controllers, MOLANG pose evaluation) — own spec tranche with a
  content expression subset, named in `What remains` item 4.
  Named follow-up (not silent): a rotated-content live proof (rotated
  asset drawing + hitting through the seal on the lead, then ports) —
  lead landed 2026-09-12, see the live-proof addendum below.

## Addendum — rotated-content live proof, lead bridge-1122 (2026-09-12)

`bridge-1122` `a4a1651` (E0) proves the rotated draw + hit live on
Forge 2860 (150 s server + launcher-free headless direct-client
`NUMERIC_IDS=example1:my_ore=253 SPAWN=1 COMBAT=1` run,
Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live fixes.

- E0 shape (lead only, `a4a1651`): proof asset
  `tools/live/my_beast_rotated.geo.json` (the shipped beast plus a
  head-bone yaw of 45 degrees — one-field delta, UVs and the 64x64
  grid untouched) ; `ModelWireCheck.testRotatedAsset` (body mesh +
  box bit-identical, head mesh moved, head box widened 9px to
  `4.5*sqrt(2)` golden `±0.397747564417433`, conservative-cover over
  the unrotated box, pure ray resolves the rotated head, texture
  loads against the rotated grid) ; `run-live.sh` `ROTATED_GEO`
  overlay (deploys the proof asset as `my_beast.geo.json` —
  proof-only, never shipped in `dist/`) ; mechanical SPI re-pin to
  `1743770` on all four bridges (additive, E0 green each — the
  compat comparateur holds, zero behaviour change).
- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — renderer client-only, regression leg only,
  zero `E_*`) ; the deployed geo is byte-identical to the proof
  asset (`cmp` at proof time — the overlay path is proven, never
  assumed).
- Client: `ready mesh=72 verts stride=8 texture=64x64 program=12`
  (the rotated bake draws — same counts, UV/texture path intact)
  then `drew instances=4 mesh=72 verts buckets=1` — the first
  rotated sampled draw through the seal (GL accepted, `E_GL_DRAW`
  silent ; four visible beasts this run — the documented visibility
  lottery) ; census 2→8 balanced (`beast=brute`, cap 8) at
  worldTicks 2..5, `spawn hp <my_beast 20.0>` + `spawn hp <my_brute
  30.0>`, exact-2.0 at 500→501 then exact-3.0 at 600→601 (elapsed 1
  each, full-health baselines 20.0 → 18.0 and 30.0 → 27.0 this run ;
  the head `mult=2.0` resolves off the YAWED head — the autoplay
  aims at the `boneBoxes` head center, and the rotation is about
  that same center, so the aim rides the box with zero autoplay
  change) ; ambient dim-0 falls at ticks 49/296/308/324 paid
  per-mob through loot with replacements (the same deterministic
  churn as every 1122 proof — the struck pair untouched) ; spawn
  kill at 1000 → gem polled at 1001 (elapsed 1) ;
  `verify-client-save.sh` world == pure union (1274 cells, `1,253`
  via `NUMERIC_IDS`) ; zero `E_*` / linkage (the only `Caused by`
  lines are the known benign gem-model bakes, same signature as
  every 1122 proof since item registration).
- Trouvaille (live ops, no code impact): the client overlay is a
  DEV-only proof step (stage via `AUTOPLAY=1 run-client.sh`, then
  `cp` the proof asset over the staged `my_beast.geo.json` in an
  isolated `PRISM_DIR` — keep-or-stage would otherwise keep the
  shipped geo) ; the isolated instance dir is disposable and the
  server config is overwritten on every `run-live.sh` run, so the
  next normal run re-deploys the shipped beast with no reset step —
  nothing proof-shaped pollutes the repos (one stray
  `forge-installer.jar.log` landed in the bridge tree from the run,
  deleted same session).
- `PORT_QUEUE` new row `Beast rotation bake+proof`
  (`BRIDGE_PARITY.md`): `TODO | live | TODO | TODO` (lead live,
  three dispatch ports TODO — this addendum is the dispatch-port
  rationale, never silent). Named follow-up: one 150 s server +
  `SPAWN=1 COMBAT=1` rotated-draw leg per sibling (same bar as the
  lead live, each with its era-native anchors).
