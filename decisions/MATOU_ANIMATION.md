---
type: spec
status: active
maturity: prototype
scope: spi
roadmap: -
---

# MatouAnimation — declarative Bedrock animation clips in SPI, MOLANG eval and GPU pose contract

Date: 2026-09-12
Status: active

## Problem

The beast is frozen in bind pose. Bedrock authors articulate models with
animation documents (keyframed `rotation` / `position` / `scale` channels
per bone, driven by MOLANG expressions such as
`math.cos(query.modified_distance_moved * 38.17) * 80.0`), layered by
animation controllers. Three consumers need the same motion and disagree
by construction if each bridge hand-rolls it: the renderer (per-frame
bone transforms), the hitboxes (`boneBoxes` must ride the pose or head
shots pass through a turned head), and content (one declarative asset,
never per-version joint code). Hand-evaluating MOLANG per bridge is the
Conventions-divergence class: no dériveur, no comparateur.

A second structural fact constrains the delivery path (user decision
2026-09-12, `GPU per-instance`) : the renderer instances ONE shared
static mesh (`InstancedMeshRenderer`, one VBO, per-instance
pos/yaw/scale only). A per-entity walk phase (each mob's own distance
clock) cannot ride a single CPU-rebaked mesh without splitting the batch
per phase — the batching the `GPU_INSTANCING.md` promotion has just
standardised. The runtime path is therefore per-instance bone matrices
over the static VBO (GPU skinning), never a CPU mesh re-bake per tick.
A CPU posed bake exists only as the gate oracle that proves the matrices
(bit-for-bit cross-check, never uploaded).

## Decision

The motion lives once, as a Blockbench Bedrock animation document,
parsed and evaluated purely in `matou-spi` (`fr.iamacat.spi.model`,
Java 8, zero MC, zero GL, zero dependency). Bridges consume poses and
matrices, never the file, never a MOLANG string.

E0 (this tranche) is SPI-only: MOLANG subset evaluator, animation
document parser, single-clip evaluator, pose-to-matrices contract,
posed hitboxes, skinned-mesh layout, and the `ModelCheck` battery.
Zero bridge change — no re-pin, no live re-proof, no `PORT_QUEUE` move,
no new `E_FORGE_*` (bind-pose-rotation E0 precedent,
`MATOU_MODEL.md`).

### Frozen Bedrock subset (document envelope)

Animation documents are separate files (`*.animation.json` at the bridge
holder later; E0 parses strings, no file IO in SPI — same split as
`MatouModelParser`). Sources: `bedrock.dev/docs/stable/Animations`,
Microsoft Learn `Animations Overview` + `Animations vs. Animation
Controllers`, `bedrock-json-schemas/animation.json` (all consulted
2026-09-12; the freeze below is a strict subset, never an extension).

- Top level: `format_version` string required (value recorded, ignored —
  geometry precedent), `animations` required non-empty object. Any other
  top-level key refuses (`E_ANIM_DOC:shape` — never a silent drop).
- Clip names must match `^animation\.` (`E_ANIM_NAME:shape` otherwise —
  the schema pattern, enforced not assumed).
- Per clip, frozen fields: `loop` optional (absent or `false` = clamp at
  the ends, `true` = wrap, `"hold_on_last_frame"` = clamp — same
  observable as false for single-clip eval, kept distinct for the
  controller tranche), `animation_length` optional finite `> 0`
  (defaults to the last keyframe time; when present it must be `>=`
  the last keyframe time — keys past the length would never play,
  `E_ANIM_LENGTH:short`), `anim_time_update` optional MOLANG string in
  the frozen subset (absent = caller time is the clip time),
  `bones` required non-empty object. Refused clip keys, each a named
  follow-up never a silent default: `blend_weight`
  (`E_ANIM_BLEND`), `override_previous_animation`
  (`E_ANIM_OVERRIDE` — single-clip eval always starts from bind, which
  is the override-true semantic; the false/layered semantic is the
  multi-clip follow-up), `particle_effects` / `sound_effects` /
  `timeline` (`E_ANIM_FX`), any other unknown key
  (`E_ANIM_CLIP:shape`).
- Per bone: keys are a subset of `rotation` / `position` / `scale`, at
  least one present (`E_ANIM_CHANNEL:empty` otherwise); `relative_to`
  refuses (`E_ANIM_RELATIVE`); any other key refuses
  (`E_ANIM_CHANNEL:shape`). A bone name absent from the model refuses
  at apply time (`E_ANIM_BONE:unknown` — the parser cannot know the
  model; the evaluator checks against it, never skips).
- Channel value forms (per component a finite number or a frozen MOLANG
  string; the vanilla walk shape `["expr", 0.0, 0.0]` is the primary
  form): a bare number or bare MOLANG string (broadcasts to all three
  components), a 1-array (all three), a 3-array (per component), or a
  keyframe object mapping decimal time strings to any of the three
  value forms. A 2-array refuses
  (`E_ANIM_CHANNEL:shape`); keyframe times must be finite `>= 0` and
  strictly increasing after sort (`E_ANIM_KEY:time`); at least one key
  (`E_ANIM_KEY:empty`); per-key `pre` / `post` lerp-mode objects refuse
  (`E_ANIM_KEY:shape` — interpolation is linear, always; cubic/step
  modes are a named follow-up).
- `scale` is uniform-only (Bedrock parity): scalar, 1-array, or 3-array
  with `x == y == z` — a non-uniform triple refuses
  (`E_ANIM_CHANNEL:scale`). Scale is finite and `> 0`, checked at parse
  for literals and at eval for expressions — zero has no delta-inverse
  and negative flips winding, both refuse loudly under the same code.
- Units: `rotation` degrees (same Euler convention as the bind bake:
  x-then-y-then-z extrinsic, `R = Rz * Ry * Rx`, right-handed),
  `position` Bedrock px (same space as geometry `origin`/`pivot`),
  `scale` unitless multiplier about the bone pivot.
- The JSON envelope reuses the shared reader: malformed JSON surfaces
  `E_MODEL_JSON:*` (cited here so no `E_ANIM_JSON` duplicate ever
  appears — anti-doublon rule, `AGENTS.md` section 3).

### Frozen MOLANG subset

- Queries (anything else, including `query.is_baby`,
  `query.anim_pos`, `query.anim_speed`, refuses
  `E_ANIM_MOLANG:query`): `query.anim_time` (wrapped clip time, s),
  `query.life_time` (caller-supplied entity age, s),
  `query.modified_distance_moved` (caller-supplied walk driver, blocks),
  `query.delta_time` (caller-supplied tick step, s).
- Variables `variable.*`: caller-supplied floats; a missing variable
  reads `0.0` (Bedrock parity — uninitialised variables are zero —
  documented here, not silent). Any other namespace (`this`, `temp`,
  `context`, `geometry`, `material`, `texture`) refuses
  (`E_ANIM_MOLANG:scope`); the Bedrock `- this` idiom therefore refuses
  loudly (`E_ANIM_MOLANG:this` — entity-field binding is a named
  follow-up, never smuggled).
- Functions `math.*` (also accepted with a capital `Math.` prefix and
  normalised — vanilla ships `Math.cos`; both spellings evaluate
  identically): `sin cos sqrt abs floor ceil round clamp lerp max min
  pow`. Any other function refuses (`E_ANIM_MOLANG:fn`).
- Operators: `+ - * / %`, comparisons `< <= > >= == !=` (1.0/0.0),
  `&& || !`, unary minus, parentheses, ternary `?:`. Assignment (`=`)
  and statement separators (`;`) refuse (`E_ANIM_MOLANG:assign`).
  Division by zero yields the Java double result (`Infinity`/`NaN`),
  which refuses at the channel boundary (`E_ANIM_MOLANG:nan` — a NaN
  pose never reaches a matrix).
- Named divergence D-ANIM-1 (deliberate, Bedrock trig units are NOT
  claimed here): `sin`/`cos` take radians (Java `Math` parity).
  Proof assets are authored against radians; any Bedrock-ported asset
  converts at authoring time. No silent reinterpretation either way.

### Evaluation semantics (single clip)

- Entry: `evaluate(clip, timeSeconds, ctx)` — pure, deterministic.
  `timeSeconds` must be finite and `>= 0` (`E_ANIM_TIME` otherwise).
  `ctx` carries the four queries plus the variable map (null map =
  empty, documented).
- `anim_time_update`, when present, evaluates first with
  `query.anim_time = timeSeconds` and its result becomes the clip time;
  absent, the clip time is `timeSeconds`. The evaluated time then wraps
  (`loop: true` — `t mod length`; a looped clip with `length <= 0`
  refuses `E_ANIM_LENGTH:empty`, a modulo by zero would be silent) or
  clamps (false / `"hold_on_last_frame"`).
- Each animated component resolves to a float at the wrapped time:
  flat (non-keyframed) values are single keys at `t = 0.0`, hence
  continuous expressions; keyframed components resolve every key value
  (numbers directly, MOLANG strings with `query.anim_time` = wrapped
  time) then lerp linearly between the surrounding keys; before the
  first key the first value holds, after the last the last value holds
  (clamped legs) — for a looped clip the last-to-first span wraps only
  through the modulo, never through an extra segment.
- The pose is sparse: bones the clip does not name stay at bind; an
  empty evaluation (clip with no resolvable motion at time `t` — e.g.
  all-zero constants) is still a valid identity pose, never an error.
  Multi-clip layering (additive channels across clips, controllers,
  transitions) is refused by absence: the evaluator takes exactly one
  clip — a second clip is a second call whose composition is the
  named follow-up, never an overloaded signature.
- A null pose argument at any apply site refuses (`E_ANIM_POSE:null`);
  a pose naming a bone the model does not carry refuses
  (`E_ANIM_BONE:unknown`). Absent = bind is the only default, and it is
  written here.

### Pose application order (CPU oracle and GPU matrices agree)

Per bone level, with `Rb = bind Euler`, `Rp = pose Euler offset`,
`P = bind pivot (px)`, `O = pose position offset (px)`, `s = pose
uniform scale`:

`p' = P + O + R(Rb + Rp) * S(s) * (p - P)`

then the parent chain innermost-first exactly like the bind bake
(`MatouModel` chain order, unchanged). The cube level carries no pose.
Normals rotate by `R(Rb + Rp)` translation-free and renormalize; UVs
never move. A zero pose (`Rp = 0`, `O = 0`, `s = 1` everywhere) skips
bit-for-bit: identity-posed meshes equal `bakeMesh()` float-for-float
and identity-posed boxes equal `boneBoxes()` field-for-field (the
compat comparateur pins it — bridges re-pin without re-proof on its
strength, rotation precedent).

### GPU delivery contract (bridge tranches consume this, E0 only proves it)
- `poseDeltaMatrices(pose)`: per-bone 4x4 row-major `float[16]`,
  model space, parents composed (`W = W_parent * T(P + O) * R(Rb + Rp)
  * S(s) * T(-P)`), delivered as the pose delta `D = W_pose *
  W_bind^-1` (rigid-plus-uniform-scale inverse, computed in double,
  narrowed once). The shader skins bind positions directly
  (`worldPos = D_bone * bindPos`) — no inverse-bind upload, no VBO
  content change. An identity pose yields identity matrices (the
  delta comparateur pins it). Pure floats, zero GL import — the bridge
  uploads them verbatim as instanced attributes/uniforms at the
  consumer tranche.
- `bakeSkinnedMesh()`: additive mesh layout for the skinned shader,
  stride 9 (`pos3, uv2, normal3, bone1` — bind positions, `bone1` =
  file-order bone index as float). `bakeMesh()` (stride 8) is
  untouched — existing VBO uploads and goldens never move.
- `bakePosedMesh(pose)` (stride 8, same layout as `bakeMesh()`): the
  gate oracle ONLY — it proves `poseDeltaMatrices` by cross-check
  (delta-transformed bind corners equal the oracle mesh within `1e-5`). It is never the runtime path (per-instance
  phases would fork the batch — the decided GPU route).
- `posedBoxes(pose)` / `placedPosedBoxes(x, y, z, pose)`: conservative
  axis-aligned union over the posed corners per non-empty bone
  (rotation pre-inflation order unchanged from the bind bake);
  `placedBoxes` stays the bind-pose entry, never overloaded.

### Thrown set (SPI-owned, cited here so no bridge redefines them)

`E_MODEL_JSON:*` (shared envelope reader — see above),
`E_ANIM_DOC:missing/shape` (top level),
`E_ANIM_NAME:shape` (clip-name pattern),
`E_ANIM_CLIP:shape/empty` (unknown clip key / no animation),
`E_ANIM_BONE:unknown` (pose or clip bone absent from the model),
`E_ANIM_CHANNEL:shape/empty/scale` (bad channel key / no channel /
non-uniform scale),
`E_ANIM_KEY:time/empty/shape` (bad keyframe time / no keys /
pre-post objects),
`E_ANIM_LENGTH:missing/short/empty` (bad `animation_length` / keys
past it / zero-length loop),
`E_ANIM_BLEND`, `E_ANIM_OVERRIDE`, `E_ANIM_FX`, `E_ANIM_RELATIVE`
(refused future fields),
`E_ANIM_MOLANG:empty/syntax/query/scope/fn/assign/nan/this`
(expression refusals),
`E_ANIM_TIME` (bad evaluation time),
`E_ANIM_POSE:null`.

### Gate `ModelCheck` animation battery

MOLANG goldens (arithmetic precedence, queries, `variable.*`
default-0, `math.*` incl. the `Math.` alias, ternary, short-circuit
`&&`/`||`), refusal battery over the whole `E_ANIM_MOLANG` catalog;
parse goldens (walk clip with flat MOLANG rotation + 2-key position
channel, uniform-scale acceptance, `anim_time_update` passthrough);
eval goldens (flat-expression continuity at three times, keyframe
midpoint lerp exact, loop wrap `t mod length`, hold/clamp freeze,
`animation_length` default = last key time); compat comparateur
(identity pose mesh float-identity + boxes field-identity);
matrix cross-check (oracle mesh vs delta-transformed bind corners
`1e-5`, identity-pose delta is identity, yaw-pose head matrix golden, winding over the posed oracle mesh);
skinned layout golden (stride 9, bone indices 0/1, UVs unmoved under
pose); apply-time refusals (`E_ANIM_BONE:unknown`,
`E_ANIM_POSE:null`, `E_ANIM_TIME`).

## Gates

- `spi/tools/check.sh` green incl. `ok model-check` (animation
  battery above, all pre-existing goldens unmodified).
- `hub/tools/check.sh` green (index lists this file; no bridge file
  touched, no live re-proof — pure SPI tranche, rotation-E0
  precedent).
- 4 bridges NOT re-pinned (additive-only SPI: no existing byte
  changes — the compat comparateur holds; pins move at the consumer
  tranche, never here).

## What remains (re-opens as tranches, not silently)

1. Lead-bridge consumer E0 (`bridge-1122`) — DONE E0 2026-09-12
    (`1640914`, stages 1-2 green, live proof TODO — see the consumer
    addendum below): holder loads `my_beast.animation.json` beside the
    geo (same keep-or-copy deploy rule), skinned shader + `GlBackend`
    matrix upload at the era anchors, one clip selected per tick
    (wire-time selection table, content-driven later), posed hitboxes
    on the combat path. `PORT_QUEUE` row `Beast animation`
    (`TODO | e0 | TODO | TODO`).
2. Lead live proof: same bar as every lead E0 (150 s server +
   `SPAWN=1 COMBAT=1` animated-draw legs — `drew instances=` with the
   skinned program, census, exact-2.0 + exact-3.0 off the posed head,
   pure-union saves, zero `E_*`). Flips the row to
   `TODO | live | TODO | TODO`.
3. Sibling dispatch E0 + live (same bar per sibling, era-native
   anchors), row closed `live x4`.
4. Multi-clip layering + controllers (`blend_weight`,
   `override_previous_animation: false`, state machines, transitions)
   — own spec tranche with a blending-semantics subset.
5. Expression follow-ups: `this` entity-field binding, FX timelines
   (`particle_effects` / `sound_effects` / `timeline`),
   `relative_to`, non-uniform scale, `pre`/`post` lerp modes,
   further `query.*` / `math.*` coverage — each refused loudly until
   its tranche, never smuggled.

## Addendum — beast animation consumer E0, lead bridge-1122 (2026-09-12)

Lands `What remains` item 1 as E0: the GPU per-instance route over the
static VBO, stages 1-2 green on the lead, live proof TODO — same bar
as every lead E0.

- Proof asset `bridge-1122/tools/live/my_beast.animation.json` (the
  shipped walk clip: `animation.beast.walk`, `loop: true`, head
  rotation off `query.life_time` (`math.sin(t * 3.0) * 30.0` — the E0
  clock is the entity age, see below), body position bob over keys
  `0.0`/`0.5` (length defaults to `0.5`); bones are the shipped
  `body`+`head`, never the SPI `leg` fixture).
- Holder `bridge-1122/java/src/fr/iamacat/bridge/model/BeastAnimation.java`
  (zero MC, lazy singleton over `ANIM_PATH`
  `config/matoubridge/my_beast.animation.json`): `load` refuses
  `E_ANIM_GEO:null/unreadable` and propagates the SPI `E_ANIM_*` +
  `E_MODEL_JSON` catalog (never redefined); `sealClip` is the
  wire-time mob-to-clip table (pure like `BeastModel.sealCombat` —
  existence rides `clipFor`, so a swapped file missing the sealed clip
  refuses at first use, never silently); `clipFor`/`poseFor` serve the
  sealed clip per mob (plus pure overloads taking the file instance —
  the gate battery never touches the production path). Thrown set
  addition (bridge-local, cited here so no sibling redefines it):
  `E_ANIM_GEO:null/unreadable`, `E_ANIM_WIRE:null/empty/unknown/unwired`.
- Renderer `InstancedMeshRenderer` (1122-native anchors untouched):
  static VBO switches to the SPI skinned bake (stride 9: pos3, uv2,
  normal3, bone1 — `bakeMesh` stride 8 stays the gate oracle layout,
  never the upload); per-instance bone deltas ride a second instanced
  VBO (2 mat4 as 8 vec4 columns — the SPI row-major deltas transpose
  once at pack into GL columns, verbatim values, era-native order);
  skinned vertex shader branches the file-order bone index over the
  two instanced matrices (`worldPos = D_bone * bindPos`, then the
  unchanged yaw/scale/offset instance chain; normals ride
  `mat3(D)` and renormalize). `E_ANIM_SKIN:bones` refuses a non-2-bone
  beast at `initGl` (the 2-bone proof fills the guaranteed 16
  attributes exactly — the generic palette is the named follow-up).
  The `ready` line moves to `stride=9` (the live legs grep the new
  bar — an unskinned draw cannot pass silently).
- Posed hitboxes `MatouEntity.hitBoxes()` ride the sealed clip pose
  (`placedPosedBoxes` at the entity origin — head shots meet the
  turned head, never bind). Clock is the entity age
  (`ticksExisted / 20.0` for `anim_time` + `life_time`,
  `distMoved = 0.0`, `delta = 0.05`); the walk-phase driver
  (`distanceWalkedModified`) is the named live follow-up — the shipped
  walk clip already moves off `life_time` + keyframes, so E0 poses
  without it. New narrow-map row `Entity.ticksExisted I field_70173_aa`
  plus the shape-only stub field (owner discipline: read through
  declaring `Entity`, never the beast).
- Wire time `MatouBridgeMod.wireCombat` seals the clip table beside
  the combat tables (every sealed mob plays `animation.beast.walk` —
  content-driven later, multi-clip layering stays its own tranche)
  and logs `[MatouBridge] animation wired <{mob=clip}>`.
- Deploy `run-live.sh`: `dist/` ships the animation beside geo+png
  (`SHA256SUMS`), the server config receives it beside packs.cfg
  (operator-replaceable like the geo); step 6 refusal grep trips on
  `E_ANIM` too (posed hitboxes evaluate server-side — an animation
  refusal on the server is a no-regression breach, never a silent bind
  fallback). Hub `client-prism.sh` keeps-or-stages it like geo+png.
- Gate `ModelWireCheck.testShippedAnimation`: shipped clip loads
  (name, loop, length `0.5`, bones `body`+`head`), eval goldens (head
  `0` at life `0`, `+30` at life `pi/6`, body midpoint `0.5`, loop wrap
  `0.2`), seal + `poseFor` serving, skinned layout golden (stride 9,
  bind positions equal the bake, bone indices `0`/`1`), identity deltas
  are identity + identity pose bakes byte-identical (compat), posed
  head delta moves + posed head covers bind, full refusal battery
  (`E_ANIM_GEO`, `E_MODEL_JSON:syntax` via `owned.matou`,
  `E_ANIM_WIRE`, `E_ANIM_BONE:unknown` via the `leg` clip against the
  shipped model).
- Siblings mechanical re-pin only (1710 `951e2d6`, 1165 `9fc6475`,
  1201 `7523380` to `170bb28` — additive, E0 green each, zero behaviour
  change on the compat comparateur; no holder/shader/png on their side
  yet — this addendum is the dispatch-port rationale, never silent).
- `PORT_QUEUE` new row `Beast animation, skinned pose` (`BRIDGE_PARITY.md`):
  `TODO | e0 | TODO | TODO`.
- Parity gap (dim 4, declared here): `E_ANIM_GEO` + `E_ANIM_WIRE` +
  `E_ANIM_SKIN` exist on 1122 only until the dispatch ports land them
  on the siblings ; no new `E_FORGE_*`, no new `forge/src` file, no SPI
  change (pin `170bb28` moves, bytes additive).
- eSLOC note (advisory, never a gate): lead `InstancedMeshRenderer`
  378 (72 under the 450 plafond); the `Molang` 586 + `MatouModel` 649
  slim-down stays the pending decision (table-driven, never satellite
  split — untouched by this tranche, norme et logique never mixed).
- Named follow-ups blocking live (not silent): 150 s server re-proof
  (animation refusal grep green, world == pure union) + headless
  direct-client `SPAWN=1 COMBAT=1` legs proving the skinned draw
  (`stride=9` in the `ready` line, `drew instances=` with buckets,
  census 2→8, exact-2.0 + exact-3.0 off the posed head, saves pure
  union, zero `E_*`); walk-phase driver (`distanceWalkedModified`
  mapping + per-mob distance clock); generic bone palette (3+ bones);
  sibling dispatch E0+live (same bar per sibling, era-native anchors).

## Addendum — beast animation live proof, lead bridge-1122 (2026-09-12)

`bridge-1122` `1640914` (E0) + `70dd14b` (harness) proves the
skinned draw + posed hit live on Forge 2860 (150 s server +
launcher-free headless direct-client
`NUMERIC_IDS=example1:my_ore=253 SPAWN=1 COMBAT=1` run,
Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live code
fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — renderer client-only, regression leg only,
  zero `E_*`) ; `[MatouBridge] animation wired
  <{my_beast=animation.beast.walk, my_brute=animation.beast.walk}>`
  in the boot log ; the deployed animation is byte-identical to the
  proof asset (`cmp` at proof time — the deploy path is proven,
  never assumed).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=12`
  (the skinned bake draws — same counts, UV/texture path intact)
  then `drew instances=3 mesh=72 verts buckets=1` — the first
  skinned sampled draw through the seal (GL accepted, `E_GL_DRAW`
  silent ; three visible beasts this run — the documented
  visibility lottery) ; census 2→8 balanced (`beast=brute`, cap 8)
  at worldTicks 2..5, `spawn hp <my_beast 20.0>` + `spawn hp
  <my_brute 30.0>`, exact-2.0 at 501 then exact-3.0 at 601
  (elapsed 1 each, full-health baselines 20.0 → 18.0 and 30.0 →
  27.0 this run ; the head `mult=2.0/3.0` resolves off the POSED
  head — the autoplay aims at the `boneBoxes` head center and the
  hitboxes ride `placedPosedBoxes`, so the `life_time` sway needs
  zero autoplay change) ; spawn kill at 1000 → gem polled at 1001
  (elapsed 1) ; `verify-client-save.sh` world == pure union (1274
  cells, `1,253` via `NUMERIC_IDS`) ; zero `E_*` / linkage (the
  only `Caused by` lines are the known benign gem-model bakes,
  same signature as every 1122 proof since item registration).
- Trouvaille (live ops, no logic impact): the E0 shipped the
  `Entity.ticksExisted` row in `tools/live/want.tsv` plus the
  shape-only stub field, but neither 53 counter moved — the derive
  failed loud (`E_SRG_DERIVE:want 53 lines, got 54`, never a
  silent default). Fixed harness-only before the proof:
  `bridge-1122` `70dd14b` (comment + `pin_field
  .../Entity/ticksExisted` + drift check 53→54, no logic change)
  and hub `dcd4f22` (era-1.12 derive 53→54 — only 1122 rides
  `live_derive_mcp_anchor`, siblings untouched).
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `TODO | live | TODO | TODO` (lead live,
  three dispatch ports TODO — this addendum is the dispatch-port
  rationale, never silent). Named follow-ups: one 150 s server +
  `SPAWN=1 COMBAT=1` skinned-draw leg per sibling (same bar as the
  lead live, each with its era-native anchors), walk-phase driver
  (`distanceWalkedModified` mapping + per-mob distance clock),
  generic bone palette (3+ bones).

## Addendum — beast animation dispatch E0, bridge-1165 (2026-09-12)

First dispatch port of the lead consumer (`bridge-1122` `1640914`):
`bridge-1165` `bf37900` lands E0 (stages 1-2 green, live proof TODO),
era-native 1.16.5 anchors throughout, zero SPI change (pin `170bb28`
already shared — no re-pin).

- Holder `java/src/fr/iamacat/bridge/model/BeastAnimation.java`
  verbatim (zero MC, `diff` clean) ; proof asset
  `tools/live/my_beast.animation.json` byte-identical (`cmp` clean —
  hub `tools/client-prism.sh` stages it with no script change, the
  bridge file simply exists now).
- Renderer `InstancedMeshRenderer` (1165-native shapes untouched):
  skinned stride-9 static bake + `a_bone` at location 3, instance
  slots shifted 3-6 to 4-7, bone deltas at 8-15 over `Lwjgl3Backend`
  (its `vertexAttribDivisor` carries the second instanced VBO —
  measured, never assumed); event projection upload plus the rebuilt
  camera view stay exactly as the rotation tranche left them (the
  event MatrixStack top still feeds nothing); per-bucket bone pack
  with transpose-once columns beside the eye-relative instance repack;
  `ready` moves to `stride=9`. `E_ANIM_SKIN:bones` guards the 2-bone
  ceiling at `initGl` like the lead.
- Posed hitboxes ride `placedPosedBoxes` on the entity-age clock
  (`ticksExisted / 20.0`, read through declaring `Entity`, never the
  beast); the origin stays `getPosX/Y/Z` (1.16.5 keeps no `posX`
  fields — the 1.12 field shape does not port). `wireCombat` seals
  the clip table beside the combat tables with the same
  `animation wired <...>` log line.
- Harness: narrow map 59→60 (`Entity/field_70173_aa/ticksExisted`
  row + shape-only stub field + `pin_field`, same SRG name as the
  lead) ; hub `tools/live-derive.sh` era-snapshot assert 59→60
  (harness-only, fixed in this tranche — the lead's missing-counter
  trouvaille is not repeated: the 1201-era assert beside it stays
  59, untouched); `E_ANIM` joins the server refusal grep ; the
  animation ships in `dist/` (`SHA256SUMS`) and deploys beside
  geo+png.
- Gate `bridge-1165/tools/check.sh` green incl. the ported
  `ModelWireCheck.testShippedAnimation` (battery text-identical to
  the lead — proven live, not just green: asset removed refuses
  `E_ANIM_GEO:unreadable` out of the new battery, never silent).
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `TODO | live | e0 | TODO` (first dispatch
  cell, live proof TODO — same bar as the lead live: 150 s server +
  `SPAWN=1 COMBAT=1` skinned-draw legs with the 1165 era anchors).
- eSLOC note (advisory, never a gate): 1165
  `InstancedMeshRenderer` 441 (9 under the 450 plafond ; lead 378 —
  the delta is the pre-existing camera rebuild + NaN guard, not the
  animation).
- Named follow-ups (unchanged order): 1165 live proof, then 1201,
  then 1710 (smallest era delta first); walk-phase driver,
  generic bone palette, multi-clip layering stay later tranches.

## Addendum — beast animation live proof, bridge-1165 (2026-09-12)

`bridge-1165` `bf37900` (E0) proves the skinned draw + posed hit
live on Forge 36.2.42 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, no `NUMERIC_IDS`
flattening era, Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) —
zero live code fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, `example1:my_ore`+stone — renderer client-only,
  regression leg only, zero `E_*`) ; `[MatouBridge] animation
  wired <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time — the deploy path is proven, never assumed).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=12`
  (the skinned bake draws — same counts, UV/texture path intact)
  then `drew instances=1 mesh=72 verts buckets=1` — the first
  skinned sampled draw through the seal on 1165 (GL accepted,
  `E_GL_DRAW` silent ; first leg drew 0, second drew 1 — the
  documented visibility lottery, never a code fix) ; census 2→8
  balanced (`beast=brute`, cap 8) at worldTicks 2..5, `spawn hp
  <my_beast 20.0>` + `spawn hp <my_brute 30.0>`, exact-2.0 at 501
  (20.0 → 18.0 full-health) then exact-3.0 at 601 (11.0 → 8.0
  ambient-damaged baseline, drop exact — the known 1165 churn at
  ticks 308/324, same class as every 1165 proof ; the head
  `mult=2.0/3.0` resolves off the POSED head, zero autoplay
  change) ; spawn kill at 1000 → gem polled at 1001 (elapsed 1) ;
  `verify-client-save.sh` world == pure union (1274 cells, native
  names, no `NUMERIC_IDS`) ; zero `E_*` / linkage / `Caused by`.
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `TODO | live | live | TODO` (first
  dispatch cell live, two ports TODO — same bar as the lead live,
  each with its era-native anchors). Named follow-ups (unchanged
  order): 1201, then 1710; walk-phase driver, generic bone
  palette, multi-clip layering stay later tranches.

## Addendum — beast animation dispatch E0, bridge-1201 (2026-09-12)

Second dispatch port of the lead consumer (`bridge-1122` `1640914`):
`bridge-1201` `c28e1d5` lands E0 (stages 1-2 green, live proof TODO),
era-native 1.20.1 anchors throughout, zero SPI change (pin `170bb28`
already shared — no re-pin).

- Holder `java/src/fr/iamacat/bridge/model/BeastAnimation.java`
  verbatim (zero MC, `diff` clean) ; proof asset
  `tools/live/my_beast.animation.json` byte-identical (`cmp` clean
  against both the lead and the 1165 port — hub
  `tools/client-prism.sh` stages it with no script change, the
  bridge file simply exists now).
- Renderer `InstancedMeshRenderer` (1201-native shapes untouched):
  skinned stride-9 static bake + `a_bone` at location 3, instance
  slots shifted 3-6 to 4-7, bone deltas at 8-15 over `Lwjgl3Backend`
  (its `vertexAttribDivisor` carries the second instanced VBO —
  measured, never assumed); event `getPoseStack`/`getProjectionMatrix`
  upload plus the JOML `Matrix4f.get` path stay exactly as the
  rotation tranche left them; per-bucket bone pack with
  transpose-once columns beside the eye-relative instance repack;
  `ready` moves to `stride=9`. `E_ANIM_SKIN:bones` guards the 2-bone
  ceiling at `initGl` like the lead.
- Posed hitboxes ride `placedPosedBoxes` on the entity-age clock
  (`tickCount / 20.0`, read through declaring `Entity`, never the
  beast); the origin stays `getX/Y/Z` (Mojmap getters — the 1.12
  `posX` field shape does not port, and the 1.16.5 `getPosX/Y/Z`
  names do not port either). `wireCombat` seals the clip table
  beside the combat tables with the same `animation wired <...>`
  log line.
- Harness: narrow map 59→60 (`Entity/tickCount` Mojmap row +
  shape-only stub field + `pin_field`, the 1.20 equivalent of the
  lead `ticksExisted` row) ; hub `tools/live-derive.sh` era-1.20
  snapshot assert 59→60 (harness-only, fixed in this tranche) ;
  `E_ANIM` joins the server refusal grep ; the animation ships in
  `dist/` (`SHA256SUMS`) and deploys beside geo+png.
- Gate `bridge-1201/tools/check.sh` green incl. the ported
  `ModelWireCheck.testShippedAnimation` (battery text-identical to
  the lead — proven, not just green: asset removed refuses
  `E_ANIM_GEO:unreadable` out of the new battery, never silent).
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `TODO | live | live | e0` (second dispatch
  cell, live proof TODO — same bar as the lead live: 150 s server +
  `SPAWN=1 COMBAT=1` skinned-draw legs with the 1201 era anchors).
- Parity gap (dim 4, current): `E_ANIM_GEO` + `E_ANIM_WIRE` +
  `E_ANIM_SKIN` now exist on 1122+1165+1201, 1710 TODO ; no new
  `E_FORGE_*`, no new `forge/src` file, no SPI change (pin
  `170bb28` shared).
- eSLOC note (advisory, never a gate): 1201
  `InstancedMeshRenderer` 406 (44 under the 450 plafond ; lead 378,
  1165 441 — the delta is the pre-existing JOML event path, not the
  animation).
- Named follow-ups (unchanged order): 1201 live proof, then 1710
  (smallest era delta first is done — 1710 is the last port);
  walk-phase driver, generic bone palette, multi-clip layering stay
  later tranches.

## Addendum — beast animation live proof, bridge-1201 (2026-09-12)

`bridge-1201` `c28e1d5` (E0) proves the skinned draw + posed hit
live on Forge 47.2.0 (150 s server + launcher-free headless
direct-client `SPAWN=1 COMBAT=1` run, no `NUMERIC_IDS`
flattening era, Xvfb/llvmpipe, exit 0, host Temurin 17.0.20
machine-local `/tmp/jdk17`) — zero live code fixes.

- Server green (`JAVA17_HOME=/tmp/jdk17 D3_OFFLINE=1 sh
  tools/run-live.sh`, bind clean, ticks clean, world == pure union
  1922 cells, `example1:my_ore`+stone — renderer client-only,
  regression leg only, zero `E_*`) ; `[MatouBridge] animation
  wired <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time — the deploy path is proven, never assumed).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=15`
  (the skinned bake draws — same counts, UV/texture path intact,
  `program=15` is the 1201-native GL program, same as the rotation
  tranche) then `drew instances=3 mesh=72 verts buckets=1` — the
  first skinned sampled draw through the seal on 1201 (GL accepted,
  `E_GL_DRAW` silent ; three visible beasts this run — the
  documented visibility lottery, never a code fix) ; census 2→8
  balanced (`beast=brute`, cap 8) at worldTicks 1..4
  (flattening-era timing), `spawn hp <my_beast 20.0>` + `spawn hp
  <my_brute 30.0>`, exact-2.0 at 501 (20.0 → 18.0 full-health)
  then exact-3.0 at 601 (30.0 → 27.0 full-health, no ambient churn
  this run — the drop stays exact either way, same run-dependent
  class as the qualified-mob-view trouvaille ; the head
  `mult=2.0/3.0` resolves off the POSED head, zero autoplay
  change) ; spawn kill at 1000 → gem polled at 1001 (elapsed 1) ;
  `verify-client-save.sh` world == pure union (1274 cells, native
  names, no `NUMERIC_IDS`) ; zero `E_*` / linkage (single benign
  `Caused by` = vanilla flite narrator, same as every 1201 proof).
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `TODO | live | live | live` (second
  dispatch cell live, one port TODO — same bar as the lead live,
  each with its era-native anchors). Named follow-ups (unchanged
  order): 1710 (the last port); walk-phase driver, generic bone
  palette, multi-clip layering stay later tranches.

## Addendum — beast animation dispatch E0, bridge-1710 (2026-09-12)

Last dispatch port of the lead consumer (`bridge-1122` `1640914`):
`bridge-1710` `f953070` lands E0 (stages 1-2 green, live proof TODO),
era-native 1.7.10 anchors throughout, zero SPI change (pin `170bb28`
already shared — no re-pin).

- Holder `java/src/fr/iamacat/bridge/model/BeastAnimation.java`
  verbatim (zero MC, `diff` clean) ; proof asset
  `tools/live/my_beast.animation.json` byte-identical (`cmp` clean
  against the lead — hub `tools/client-prism.sh` stages it with no
  script change, the bridge file simply exists now).
- Renderer `InstancedMeshRenderer` (1710-native shapes untouched):
  skinned stride-9 static bake + `a_bone` at location 3, instance
  slots shifted 3-6 to 4-7, bone deltas at 8-15 over `Lwjgl2Backend`
  (the LWJGL2 path, like the lead — no `Lwjgl3Backend` divisor here);
  the Pre-captured fixed-function matrices plus the 1614-native
  `theWorld` / `renderViewEntity` / `loadedEntityList` reads stay
  exactly as the textured tranche left them; per-bucket bone pack
  with transpose-once columns beside the eye-relative instance
  repack; `ready` moves to `stride=9`. `E_ANIM_SKIN:bones` guards
  the 2-bone ceiling at `initGl` like the lead.
- Posed hitboxes ride `placedPosedBoxes` on the entity-age clock
  (`ticksExisted / 20.0`, read through declaring `Entity`, never the
  beast); the origin stays the `posX/Y/Z` fields (1.7.10 keeps MCP
  fields — the 1.12 `posX` shape ports as-is, the 1.16.5
  `getPosX/Y/Z` and 1.20.1 `getX/Y/Z` names do not port).
  `wireCombat` seals the clip table beside the combat tables with
  the same `animation wired <...>` log line.
- Harness: full-map era pin (`pin_field
  net/minecraft/entity/Entity/ticksExisted` beside the renderer
  rows — no `want.tsv` exists on 1710, the pins ARE the map, same
  searge discipline) + shape-only stub field ; `E_ANIM` joins the
  server refusal grep ; the animation ships in `dist/`
  (`SHA256SUMS`) and deploys beside geo+png.
- Gate `bridge-1710/tools/check.sh` green incl. the ported
  `ModelWireCheck.testShippedAnimation` (battery text-identical to
  the lead — proven, not just green: asset removed refuses
  `E_ANIM_GEO:unreadable` out of the new battery, never silent).
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `e0 | live | live | live` (last dispatch
  cell, live proof TODO — same bar as the lead live: 150 s server +
  `SPAWN=1 COMBAT=1` skinned-draw legs with the 1710 era anchors).
- Parity gap closed on codes: `E_ANIM_GEO` + `E_ANIM_WIRE` +
  `E_ANIM_SKIN` now exist on 4/4 bridges (gate-measured:
  `bridge-1122 local-codes` 3→0, no new `E_FORGE_*`, no new
  `forge/src` file, no SPI change).
- eSLOC note (advisory, never a gate): 1710
  `InstancedMeshRenderer` 388 (62 under the 450 plafond ; lead 378,
  1165 441, 1201 406 — the delta is the pre-existing Pre-capture +
  owner-discipline comments, not the animation) ;
  `tools/run-live.sh` 254 (far from the shell ceiling).
- Named follow-ups (unchanged order): 1710 live proof (closes the
  row); walk-phase driver, generic bone palette, multi-clip
  layering stay later tranches.

## Addendum — beast animation live proof, bridge-1710 (2026-09-12)

`bridge-1710` `f953070` (E0) proves the skinned draw + posed hit
live on Forge 1614 (150 s server + launcher-free headless
direct-client `NUMERIC_IDS=example1:my_ore=165 SPAWN=1 COMBAT=1`
run, Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live
code fixes.

- Server green (`B3_OFFLINE=1 sh tools/run-live.sh`, bind clean,
  ticks clean, world == pure union 1922 cells, ids 1,165 —
  renderer client-only, regression leg only, zero `E_*`) ;
  `[MatouBridge] animation wired
  <{my_beast=animation.beast.walk, my_brute=animation.beast.walk}>`
  in the boot log ; the deployed animation is byte-identical to
  the proof asset (`cmp` at proof time — the deploy path is
  proven, never assumed).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=3`
  (the skinned bake draws — same counts, UV/texture path intact,
  `program=3` is the 1710-native GL program, same as the rotation
  tranche) then `drew instances=1 mesh=72 verts buckets=1` — the
  first skinned sampled draw through the seal on 1710 (GL accepted,
  `E_GL_DRAW` silent ; one visible beast this run — the documented
  visibility lottery, never a code fix) ; census 2→8 balanced
  (`beast=brute`, cap 8) at worldTicks 2..5 (1710-era timing),
  `spawn hp <my_beast 20.0>` + `spawn hp <my_brute 30.0>`,
  exact-2.0 at 501 (20.0 → 18.0 full-health) then exact-3.0 at 601
  (15.0 → 12.0 ambient-damaged baseline, drop exact — the known
  1710 churn class, same as every 1710 proof ; the head
  `mult=2.0/3.0` resolves off the POSED head, zero autoplay
  change) ; spawn kill at 1000 → gem polled at 1001 (elapsed 1) ;
  `verify-client-save.sh` world == pure union (1274 cells, `1,165`
  via `NUMERIC_IDS`) ; zero `E_*` / linkage (single benign
  `Caused by` = offline Forge Version Check, same as every 1710
  proof).
- `PORT_QUEUE` row `Beast animation, skinned pose`
  (`BRIDGE_PARITY.md`): `live | live | live | live` — row closed
  (skinned animation live on 4/4 Forge runtimes). Named
  follow-ups: walk-phase driver, generic bone palette,
  multi-clip layering.

## Addendum — walk-phase driver E0, lead bridge-1122 (2026-09-12)

`bridge-1122` `4473ee2` lands the walk-phase driver as E0 (stages
1-2 green, live proof TODO): `query.modified_distance_moved` reads
the per-mob vanilla distance clock instead of the `0.0` fallback —
wiring-only, the shipped walk clip is untouched (head still sways off
`life_time`, body still bobs off keyframes, so a standing mob poses
exactly as before while any dist-driven channel phases with walked
blocks).

- Holder `BeastAnimation` gains two pure helpers (zero MC, gate
  battery without MC): `animCtx(time, distMoved)` builds the eval
  context (age rides both `anim_time` and `life_time`, `delta` stays
  the fixed tick step) and `interpDistMoved(prev, cur,
  partialTicks)` eases the previous-tick counter toward the current
  one (same shape as the position interpolation beside it).
- Forge call-sites (owner discipline, reads through declaring
  `Entity`, never the beast): `MatouEntity.hitBoxes` feeds the
  current-tick `distanceWalkedModified` (server tick, no partial);
  `InstancedMeshRenderer` feeds the partialTicks interpolation of
  `prevDistanceWalkedModified` → `distanceWalkedModified` (client
  frame smoothing).
- Harness: narrow map 54→56 (`Entity/distanceWalkedModified F`
  anchor `field_70140_Q` + `Entity/prevDistanceWalkedModified F`
  anchor `field_70141_P`, shape-only stub fields, `pin_field` pair);
  hub `tools/live-derive.sh` era-1.12 assert 54→56 (harness-only —
  the 1165/1201 asserts stay 60, untouched). The derive was
  proven pre-commit against the pinned bytes (56 lines, both `FD`
  rows resolve).
- Gate `bridge-1122/tools/check.sh` green incl. the new
  `ModelWireCheck.testWalkPhaseDriver` (`animCtx` golden, interp
  goldens incl. standing-hold, inline dist-driven strut clip rests
  at dist 0 and reaches +30 at dist pi/6 — the query flows; zero
  ctx still rests, proving the shipped clip untouched). No new
  `E_*` code, no new `forge/src` file, no SPI change (pin
  `170bb28` shared).
- `PORT_QUEUE` new row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `TODO | e0 | TODO | TODO` (lead E0, live
  proof TODO — same bar as the lead animation live: 150 s server +
  `SPAWN=1 COMBAT=1` legs with posed exact-2.0/3.0, plus a walking
  mob phasing any dist-driven channel).
- Named follow-ups (unchanged order): lead live proof, sibling
  dispatch (1710 full-map pin pair, 1165 narrow 60→62, 1201 Mojmap
  `walkDist`/`walkDistO` pair); generic bone palette, multi-clip
  layering stay later tranches.

## Addendum — walk-phase driver live proof, lead bridge-1122 (2026-09-12)

`bridge-1122` `4473ee2` (E0) proves the distance clock live on
Forge 2860 (150 s server + launcher-free headless direct-client
`NUMERIC_IDS=example1:my_ore=253 SPAWN=1 COMBAT=1` run,
Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live code
fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — renderer client-only, regression leg only,
  `E_ANIM` in the refusal grep silent) ; `[MatouBridge] animation
  wired <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log.
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=12`
  then `drew instances=3 mesh=72 verts buckets=1` through the seal
  (the interpolated distance feeds the same skinned draw, GL
  accepted, `E_GL_DRAW` silent) ; census 2→8 balanced at
  worldTicks 2..5, `spawn hp <my_beast 20.0>` + `spawn hp
  <my_brute 30.0>`, exact-2.0 at 501 (20.0 → 18.0 full-health)
  then exact-3.0 at 601 (30.0 → 27.0 full-health, no ambient churn
  this run — the drop stays exact either way ; the head resolves
  off the posed head, zero autoplay change ; the walked distance
  stays ~0 for the standing mobs, so the wiring-only clip poses
  exactly as the E0 legs), spawn kill at 1000 → gem polled at 1001
  (elapsed 1) ; `verify-client-save.sh` world == pure union (1274
  cells, `1,253` via `NUMERIC_IDS`) ; zero `E_*` (only the known
  benign gem-model `Caused by` lines, same signature as every 1122
  proof) ; the deployed animation is byte-identical to the proof
  asset (`cmp` at proof time).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `TODO | live | TODO | TODO` (lead live,
  three dispatch ports TODO — same bar as the lead live, each with
  its era-native distance anchors). Named follow-ups (unchanged
  order): sibling dispatch, then generic bone palette, multi-clip
  layering.

## Addendum — walk-phase driver dispatch E0, bridge-1165 (2026-09-12)

`bridge-1165` `6ad3e52` ports the 1122 lead driver (`4473ee2`) as
E0 (stages 1-2 green, live proof TODO): `query.modified_distance_moved`
reads the per-mob vanilla distance clock instead of the `0.0`
fallback — wiring-only, the shipped walk clip is untouched.

- Holder `BeastAnimation` verbatim (zero MC) + `testWalkPhaseDriver`
  text-identical (pure battery without MC): `animCtx` golden, interp
  goldens incl. standing-hold, inline dist-driven strut rests at 0
  and reaches +30 at pi/6.
- Forge call-sites era-native 1165 (owner discipline, reads through
  declaring `Entity`): `MatouEntity.hitBoxes` feeds the current-tick
  `distanceWalkedModified` (server tick) ; `InstancedMeshRenderer`
  feeds the partialTicks interpolation of
  `prevDistanceWalkedModified` → `distanceWalkedModified` (client
  frame smoothing, same shape as the `prevPos` interpolation beside
  it).
- Harness: narrow map 60→62 (`Entity/distanceWalkedModified F`
  anchor `field_70140_Q` + `Entity/prevDistanceWalkedModified F`
  anchor `field_70141_P`, shape-only stub fields, `pin_field` pair) ;
  hub `tools/live-derive.sh` era-1.16 assert 60→62 (harness-only —
  the 1201 assert stays 60, untouched). The derive was proven
  pre-commit against the pinned bytes (62 lines, both `FD` rows
  resolve).
- Gate `bridge-1165/tools/check.sh` green, no new `E_*` code, no new
  `forge/src` file, no SPI change (pin `170bb28` shared).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `TODO | live | e0 | TODO` (first dispatch
  port E0, live proof TODO — same bar as the lead live, each with
  its era-native distance anchors). Named follow-ups: 1165 live
  proof, then 1201, 1710, generic bone palette, multi-clip layering.

## Addendum — walk-phase driver live proof, bridge-1165 (2026-09-12)

`bridge-1165` `6ad3e52` (E0) proves the distance clock live on
Forge 36.2.42 (150 s server + launcher-free headless direct-client
`SPAWN=1 COMBAT=1` run, no `NUMERIC_IDS` flattening era,
Xvfb/llvmpipe, exit 0, host OpenJDK 1.8.0_502) — zero live code
fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, `example1:my_ore`+stone — renderer client-only,
  regression leg only, zero `E_*` / `Caused by`) ;
  `[MatouBridge] animation wired <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=12`
  then `drew instances=1 mesh=72 verts buckets=1` through the seal
  (the interpolated distance feeds the same skinned draw, GL
  accepted, `E_GL_DRAW` silent ; first leg drew 0, second drew 1 —
  the documented visibility lottery, never a code fix) ; census
  2→8 balanced at worldTicks 2..5, `spawn hp <my_beast 20.0>` +
  `spawn hp <my_brute 30.0>`, exact-2.0 at 501 (20.0 → 18.0
  full-health) then exact-3.0 at 601 (29.0 → 26.0
  ambient-damaged baseline, drop exact — the known 1165 churn at
  ticks 308/324, same as every 1165 proof ; the head resolves off
  the posed head, zero autoplay change ; the walked distance stays
  ~0 for the standing mobs, so the wiring-only clip poses exactly
  as the E0 legs), spawn kill at 1000 → gem polled at 1001
  (elapsed 1) ; `verify-client-save.sh` world == pure union (1274
  cells, native names, no `NUMERIC_IDS`) ; zero `E_*` / linkage /
  `Caused by` ; the deployed animation is byte-identical to the
  proof asset (`cmp` at proof time).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `TODO | live | live | TODO` (first dispatch
  cell live, two ports TODO — same bar as the lead live, each with
  its era-native distance anchors). Named follow-ups (unchanged
   order): then 1201, 1710, generic bone palette, multi-clip
   layering.

## Addendum — walk-phase driver dispatch E0, bridge-1201 (2026-09-12)

`bridge-1201` `ef87cd2` ports the 1122 lead driver (`4473ee2`) as
E0 (stages 1-2 green, live proof TODO):
`query.modified_distance_moved` reads the per-mob vanilla distance
clock instead of the `0.0` fallback — wiring-only, the shipped walk
clip is untouched.

- Holder `BeastAnimation` verbatim (zero MC) + `testWalkPhaseDriver`
  text-identical (pure battery without MC): `animCtx` golden, interp
  goldens incl. standing-hold, inline dist-driven strut rests at 0
  and reaches +30 at pi/6.
- Forge call-sites era-native Mojmap (owner discipline, reads through
  declaring `Entity`): `MatouEntity.hitBoxes` feeds the current-tick
  `walkDist` (server tick) ; `InstancedMeshRenderer` feeds the
  partialTicks interpolation of `walkDistO` → `walkDist` (client
  frame smoothing, same shape as the `xo` interpolation beside it).
- Harness: narrow map 60→62 (`Entity/walkDist F` Mojmap `X` +
  `Entity/walkDistO F` Mojmap `W`, shape-only stub fields,
  loop-form `pin_field` pair) ; hub `tools/live-derive.sh` era-1.20
  assert 60→62 (harness-only). The derive was proven pre-commit
  against the pinned bytes (62 lines, both `FD` rows resolve:
  `walkDist f_19787_` + `walkDistO f_19867_`).
- Gate `bridge-1201/tools/check.sh` green, no new `E_*` code, no new
  `forge/src` file, no SPI change (pin `170bb28` shared ; shell
  `run-live.sh` 439/450, loop form).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `TODO | live | live | e0` (second dispatch
  port E0, live proof TODO — same bar as the lead live, each with
  its era-native distance anchors). Named follow-ups: 1201 live
  proof, then 1710, generic bone palette, multi-clip layering.

## Addendum — walk-phase driver live proof, bridge-1201 (2026-09-12)

`bridge-1201` `ef87cd2` (E0) proves the distance clock live on
Forge 47.2.0 (150 s server + launcher-free headless direct-client
`SPAWN=1 COMBAT=1` run, no `NUMERIC_IDS` flattening era,
Xvfb/llvmpipe, exit 0, Temurin 17.0.20 via `JAVA17_HOME=/tmp/jdk17`)
— zero live code fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, `example1:my_ore`+stone — renderer client-only,
  regression leg only, zero `E_*` / `Caused by`) ;
  `[MatouBridge] animation wired <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=15`
  then `drew instances=2 mesh=72 verts buckets=1` through the seal
  (the interpolated distance feeds the same skinned draw, GL
  accepted, `E_GL_DRAW` silent ; two visible beasts this run —
  the documented visibility lottery, never a code fix ; the
  join-transient `skipped non-finite view-projection` fires once
  before the first draw, same guard as every 1201 proof) ; census
  2→8 balanced at worldTicks 1..4, `spawn hp <my_beast 20.0>` +
  `spawn hp <my_brute 30.0>`, exact-2.0 at 501 (20.0 → 18.0
  full-health) then exact-3.0 at 601 (23.0 → 20.0
  ambient-damaged baseline, drop exact — ambient falls at ticks
  73/308/324, same churn class as the 1165 308/324 proofs with
  the 1201 tick-73 falls ; the head resolves off the posed head,
  zero autoplay change ; the walked distance stays ~0 for the
  standing mobs, so the wiring-only clip poses exactly as the E0
  legs), spawn kill at 1000 → gem polled at 1001 (elapsed 1) ;
  `verify-client-save.sh` world == pure union (1274 cells, native
  names, no `NUMERIC_IDS`) ; zero `E_*` / linkage (single benign
  flite `UnsatisfiedLinkError` `Caused by`, same as every 1201
  proof, plus the known benign gem-model `ModelBakery` WARNs) ;
  the deployed animation is byte-identical to the proof asset
  (`cmp` at proof time).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `TODO | live | live | live` (second
  dispatch cell live, one port TODO — 1710 full-map pin pair).
  Named follow-ups (unchanged order): then 1710, generic bone
  palette, multi-clip layering.

## Addendum — walk-phase driver dispatch E0, bridge-1710 (2026-09-12)

`bridge-1710` `e46c538` ports the 1122 lead driver (`4473ee2`) as
E0 (stages 1-2 green, live proof TODO):
`query.modified_distance_moved` reads the per-mob vanilla distance
clock instead of the `0.0` fallback — wiring-only, the shipped walk
clip is untouched.

- Holder `BeastAnimation` verbatim (zero MC, `diff` clean against
  the lead) + `testWalkPhaseDriver` text-identical (pure battery
  without MC): `animCtx` golden, interp goldens incl.
  standing-hold, inline dist-driven strut rests at 0 and reaches
  +30 at pi/6.
- Forge call-sites era-native 1614 (owner discipline, reads through
  declaring `Entity`): `MatouEntity.hitBoxes` feeds the current-tick
  `distanceWalkedModified` (server tick) ; `InstancedMeshRenderer`
  feeds the partialTicks interpolation of
  `prevDistanceWalkedModified` → `distanceWalkedModified` (client
  frame smoothing, same shape as the `lastTickPos` interpolation
  beside it).
- Harness: full-map era pin pair (`pin_field
  net/minecraft/entity/Entity/distanceWalkedModified` +
  `pin_field
  net/minecraft/entity/Entity/prevDistanceWalkedModified` beside
  the `ticksExisted` row — no `want.tsv` exists on 1710, the pins
  ARE the map, same searge discipline) + shape-only stub fields
  (non-final floats). Both `FD` rows verified pre-commit against
  the pinned 1614 SRG (`field_70140_Q` + `field_70141_P`).
- Gate `bridge-1710/tools/check.sh` green, no new `E_*` code, no new
  `forge/src` file, no SPI change (pin `170bb28` shared ; shell
  `run-live.sh` 256/450).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `e0 | live | live | live` (last dispatch
  port E0, live proof TODO — same bar as the lead live, with the
  1614 era anchors). Named follow-ups: 1710 live proof (closes the
  row), generic bone palette, multi-clip layering.

## Addendum — walk-phase driver live proof, bridge-1710 (2026-09-12)

`bridge-1710` `e46c538` (E0) proves the distance clock live on
Forge 1614 (150 s server + launcher-free headless direct-client
`NUMERIC_IDS=example1:my_ore=165 SPAWN=1 COMBAT=1` run,
Xvfb, exit 0, host OpenJDK 1.8.0_502) — zero live code fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,165 — renderer client-only, regression leg only,
  zero `E_*`) ; `[MatouBridge] animation wired
  <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time ; single benign offline Version-Check `Caused by`, same as
  every 1710 proof).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=3`
  then `drew instances=4 mesh=72 verts buckets=1` through the seal
  (the interpolated distance feeds the same skinned draw, GL
  accepted, `E_GL_DRAW` silent ; four visible beasts this run —
  the documented visibility lottery, never a code fix) ; census
  2→8 balanced at worldTicks 2..5, `spawn hp <my_beast 20.0>` +
  `spawn hp <my_brute 30.0>`, exact-2.0 at 501 (20.0 → 18.0
  full-health) then exact-3.0 at 601 (9.0 → 6.0
  ambient-damaged baseline, drop exact — the known 1710 churn
  class ; the head resolves off the posed head, zero autoplay
  change ; the walked distance stays ~0 for the standing mobs, so
  the wiring-only clip poses exactly as the E0 legs), spawn kill
  at 1000 → gem polled at 1001 (elapsed 1) ;
  `verify-client-save.sh` world == pure union (1274 cells, `1,165`
  via `NUMERIC_IDS`) ; zero `E_*` (single benign offline
  Version-Check `Caused by` plus the benign missing gem-icon
  `TEXTURE ERRORS`, same classes as every 1710 proof ; the
  SplashProgress crash-report header only, zero `#@!@# Game
  crashed!` / unexpected exception) ; the deployed animation is
  byte-identical to the proof asset (`cmp` at proof time,
  post-run).
- `PORT_QUEUE` row `Beast animation, walk-phase driver`
  (`BRIDGE_PARITY.md`): `live | live | live | live` (row closed —
  distance clock live on 4/4 runtimes). Named follow-ups
  (unchanged order): generic bone palette, multi-clip layering.

## Addendum — generic bone palette E0, lead bridge-1122 (2026-09-12)

Lands the palette as E0 on the lead (`bridge-1122` `462ca53` over
SPI `605d393`, stages 1-2 green, live proof TODO): 1..8 bones ride
a 4xN RGBA32F bone texture on unit 1, fetched by file-order index —
the 2-bone attribute path (`8 + 4N <= 16`, full at N = 2) retires.
Route decided with operator (bone texture, `Recommended` ; uniform
array stays the named debt: simpler, but a second per-bucket upload
 beside the instance VBO with its own size ceiling — the texture
scales past 8 without a new channel).

- SPI `605d393` (additive, all pre-existing goldens unmodified) :
  `GlBackend.activeTexture` + `GL_TEXTURE0/1` + `GL_RGBA32F`
  surface, mock workflow golden (`GlBackendCheck`) ; 3-bone
  `TRIPLE` fixture + `testPaletteBones` golden (`ModelCheck`:
  parse order + hierarchy, skinned bone-2 index, three identity
  deltas, third-bone clip eval, delta-vs-oracle cross-check,
  three posed boxes). Trouvaille (render-path correctness, fixed
  here, never silent): `poseDeltaMatrices` carried the translation
  in Bedrock px while the skinned bake is blocks — any
  pivot-moving rotation displaced the skinned mesh 16x (the old
  goldens only posed identity + axis-invariant pivots, whose
  translation is exactly zero, so no gate could see it ; the CPU
  oracle and the hitboxes were always blocks-correct, which is why
  every live verdict stayed green). The translation normalizes to
  blocks at the contract boundary now (class contract comment
  updated — pixels in, blocks out), the 3-bone golden is the
  regression, bridge yaw goldens unchanged (zero translation
  there).
- Holder `BeastAnimation` (zero MC, thin forge): pure
  `packPaletteInto` (one SPI row-major delta as 4 GL columns —
  texel (column, bone) holds column `c`) + `paletteBonesOrThrow` /
  `MAX_BONES = 8` admission (the ceiling lives here, frozen by
  this tranche, never redefined per bridge).
- Renderer `InstancedMeshRenderer` (1122-native anchors untouched):
  bone texture `4 x N` RGBA32F on unit 1 (NEAREST +
  CLAMP_TO_EDGE, NPOT-safe ; `texelFetch` by
  `int(a_bone + 0.5)`, same column layout as the retired pack),
  sampler units bound once (`u_tex` 0, `u_bones` 1), per-bucket
  STREAM upload beside the instance repack ; the 8 bone attribute
  slots retire (static 0-3 + instance 4-7 only — the 16-attribute
  guarantee holds for any admitted beast) ; the `initGl` guard
  becomes the 1..8 range (`E_ANIM_SKIN:bones <n>`, same code, new
  dims) ; the staging keeps its 512-beast shape over a byte-backed
  buffer (the old `SKINNED_BONES`-based remaining check went N —
  it would have overrun past 2 bones). eSLOC renderer 381 → 375
  (6 further under the 450 plafond).
- Backends: `Lwjgl2Backend.activeTexture` on the lead (GL13) ;
  shape-only `GL13` stub beside the other GL stubs (compile
  classpath only, never runs — same discipline).
- Gate `ModelWireCheck.testBonePalette`: admission 1/2/8 + refusals
  0/9 (`E_ANIM_SKIN:bones`), column-order golden (texels hold
  columns), inline 3-bone model (index 2 + three deltas, shipped
  2-bone beast stays admitted). No new `E_*` code, no new
  `forge/src` file, pin `605d393` shared (siblings mechanical
  re-pin only — 1710 `16670ca`, 1165 `0a76f8e`, 1201 `a2068ec` :
  pin + additive `activeTexture` + era stub, E0 green each, zero
  behaviour change — their exact-2 guards stay until dispatch).
- `PORT_QUEUE` new row `Beast animation, generic palette`
  (`BRIDGE_PARITY.md`): `TODO | e0 | TODO | TODO` (lead E0, live
  proof TODO — same bar as every lead E0: 150 s server +
  `SPAWN=1 COMBAT=1` legs over the shipped beast, which now draws
  through the palette path).
- Parity gap (dim 4, declared here): `E_ANIM_SKIN` range semantics
  on 1122 only until the dispatch ports land them on the siblings ;
  `activeTexture` implemented on 4/4 backends already ; no new
  `E_FORGE_*`, no new `forge/src` file.
- Named follow-ups (unchanged order): lead live proof (palette-path
  regression on the shipped beast + a 3-bone live asset proving
  the index-2 fetch through the seal), sibling dispatch E0+live
  (same bar per sibling, era-native anchors — 1165 watches its
  444/450 renderer ceiling), multi-clip layering.

## Addendum — generic bone palette live proof, lead bridge-1122 (2026-09-12)

`bridge-1122` `462ca53` (E0) proves the palette path live on Forge
2860 (150 s server + launcher-free headless direct-client
`NUMERIC_IDS=example1:my_ore=253 SPAWN=1 COMBAT=1` run, Xvfb,
exit 0) — zero live code fixes.

- Server green (bind clean, ticks clean, world == pure union 1922
  cells, ids 1,253 — renderer client-only, regression leg only,
  zero `E_*`, zero `Caused by`) ; `[MatouBridge] animation wired
  <{my_beast=animation.beast.walk,
  my_brute=animation.beast.walk}>` in the boot log ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time, pre- and post-run).
- Client: `ready mesh=72 verts stride=9 texture=64x64 program=12`
  then `drew instances=4 mesh=72 verts buckets=1` through the seal
  (the shipped 2-bone beast now draws through the bone texture on
  unit 1, `E_GL_DRAW` silent ; four visible beasts this run — the
  documented visibility lottery, never a code fix) ; census 2→8
  balanced at worldTicks 2..5, `spawn hp <my_beast 20.0>` +
  `spawn hp <my_brute 30.0>`, exact-2.0 at 501 (20.0 → 18.0
  full-health) then exact-3.0 at 601 (30.0 → 27.0 full-health, no
  churn this run — the head resolves off the posed head, zero
  autoplay change), spawn kill at 1000 → gem polled at 1001
  (elapsed 1) ; `verify-client-save.sh` world == pure union (1274
  cells, `1,253` via `NUMERIC_IDS`) ; zero `E_*` (benign gem-model
  `Caused by` only, same as every 1122 proof) ; the deployed
  animation is byte-identical to the proof asset (`cmp` at proof
  time, post-run).
- `PORT_QUEUE` row `Beast animation, generic palette`
  (`BRIDGE_PARITY.md`): `TODO | live | TODO | TODO` (lead live,
  three dispatch ports TODO). Named follow-ups (unchanged order):
  sibling dispatch E0+live (same bar per sibling, era-native
  anchors — 1165 watches its 444/450 renderer ceiling), a 3-bone
  live asset proving the index-2 fetch through the seal,
  multi-clip layering.

## Non-goals (explicit)

CPU per-tick mesh re-bake as a runtime path (rejected by the GPU
decision above — the oracle stays test-only); animation authoring
tooling (assets are hand-written JSON, validated by the gate);
server-side visual state (the server never evaluates clips — hitboxes
are the only pose consumer outside the client renderer, same split as
the bind bake).
