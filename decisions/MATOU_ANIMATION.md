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

1. Lead-bridge consumer E0 (`bridge-1122`): holder loads
   `my_beast.animation.json` beside the geo (same keep-or-copy deploy
   rule), skinned shader + `GlBackend` matrix upload at the era
   anchors, one clip selected per tick (wire-time selection table,
   content-driven later), posed hitboxes on the combat path. Opens
   `PORT_QUEUE` row `Beast animation` (`TODO | e0 | TODO | TODO`).
   Stages 1-2 green, live proof TODO.
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

## Non-goals (explicit)

CPU per-tick mesh re-bake as a runtime path (rejected by the GPU
decision above — the oracle stays test-only); animation authoring
tooling (assets are hand-written JSON, validated by the gate);
server-side visual state (the server never evaluates clips — hitboxes
are the only pose consumer outside the client renderer, same split as
the bind bake).
