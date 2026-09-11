---
type: ruling
status: active
maturity: unrated
scope: shared
roadmap: -
---

# Minecraft backends and reproducibility — virtual hitboxes and decoupled geometry

Date: 2026-09-11
Status: active

## Problem

A central question in cross-version Minecraft modding architecture is whether
content systems (hitboxes, melee detection, mob models, rendering, and assets)
should rely on Minecraft's native backends (wrapping each version's native
classes) or be implemented as a version-independent pure engine layer.

Analysis of Minecraft vanilla mechanics across the 4 supported runtimes
(1.7.10, 1.12.2, 1.16.5, 1.20.1) and investigation of legacy systems in
`matoulib-core` reveals that relying on Minecraft's native backends destroys
simulation reproducibility and creates unsustainable technical debt.

## Analysis of Minecraft Native Limitations

### 1. Hitbox & Combat Raycast Divergence

1. **Single Coarse AABB**: Vanilla Minecraft entities possess only a single
   bounding box (`AxisAlignedBB` in 1.7/1.12, `AABB` in 1.16/1.20). Vanilla
   cannot distinguish between hits on specific bones (head, torso, limbs,
   wings). Multi-part mobs in vanilla (e.g. `EntityDragon`) rely on ad-hoc
   sub-entity hacks with rigid, hardcoded physics.
2. **Precision & Coordinate Inconsistencies**: Floating-point vs. double-precision
   conversions, yaw/pitch angular conventions, and bounding box offsets vary
   across Minecraft versions. A raycast aimed at a boundary angle can hit in
   1.7.10 and miss in 1.20.1.
3. **Asymmetric Client/Server Validation**:
   - In vanilla, the client performs a raycast (`EntityRenderer.getMouseOver`)
     using interpolated partial ticks (`partialTicks`) against the entity's
     bounding box.
   - Upon click, the client transmits `C02PacketUseEntity` containing only the
     integer entity ID, with no hit coordinates, ray origin, or targeted bone.
   - The vanilla server validates solely that the distance between player origin
     and entity origin is below a threshold (e.g., `getDistanceSqToEntity < 36`
     in 1.7.10). For large or elongated entities (e.g. dragons, bosses), this
     causes severe bugs: distant limbs cannot be hit despite the player aiming
     directly at them (BUG-042 in legacy logs).
   - Identical physical actions yield diverging outcomes between two runs and
     across versions.

### 2. Model & Asset Wrapper Combinatorial Explosion

Attempting to build a "unified model wrapper" that delegates to each Minecraft
version's native renderer is technically feasible but creates an unmaintainable
maintenance burden:
1. **Four Incompatible Render Pipelines**:
   - **1.7.10**: `ModelBase` / `ModelRenderer` executing immediate OpenGL draw
     calls (`glBegin`/`glEnd` or legacy display lists) via LWJGL 2.
   - **1.12.2**: `RenderLivingBase` with partial JSON block models and Forge's
     experimental animation pipeline.
   - **1.16.5**: Complete rendering overhaul using `RenderType`, `RenderLayers`,
     `VertexConsumer`, Mojang's `MatrixStack`, and LWJGL 3.
   - **1.20.1**: Modernized shader pipeline, `BakedModel`, and rewritten buffer
     management.
2. **Performance Bottlenecks**: Vanilla rendering relies on CPU vertex staging
   into `Tessellator` / `BufferBuilder`. Rendering tens or hundreds of complex
   animated entities causes severe CPU draw-call saturation.
3. **Fragile Glue Code**: A wrapper approach would require several thousand lines
   of volatile glue code per bridge, binding the project's data schema to Mojang's
   internal refactors.

### 3. Findings from `matoulib-core`

Inspection of `/home/iamacat/Documents/GitHub/matou/matoulib-core/` demonstrates
that decoupled solutions already existed:
- `core/hit/` (`AABBd`, `BoneHitBox`, `HitTester`, `RayHit`): Pure geometric
  math utilizing the slab ray-AABB intersection method across bone bounding boxes.
  The system is GL-free and Minecraft-free, enabling identical execution on both
  the client (for instant client-side prediction) and the server (for authoritative
  validation).
- `client/gpu/instancing/` (`GeoInstancedRenderer`): GPU-instanced drawing via
  `glDrawArraysInstancedARB` packing mob transforms and bone palettes into GPU
  buffers/textures, reducing hundreds of mob draw calls to a single draw call.

However, the architectural failure of legacy `matoulib-core` was **monolithic
coupling**: pure geometric algorithms were co-located in the same artifact as
version-specific 1.7.10 Forge imports and ASM/mixins. This triggered the
strict `zero-mc-import` and `no-legacy-matoulib` gates in `matou-dev`.

## Decision

1. **Separation of Decision vs. Presentation (`LAYER_Q1_Q11.md`)**:
   - All spatial calculations, hitboxes, combat ray-testing, and bone-level
     geometry belong exclusively in `matou-spi` (Java 8, zero Minecraft imports,
     zero OpenGL imports).
   - The simulation runs identically offline in CLI JUnit tests without
     instantiating Minecraft.
2. **Virtual Hitboxes**:
   - Entities declare their geometric bounding volumes per bone (`BoneBox`).
   - Melee hit detection evaluates the exact same pure `HitTester` ray-box
     algorithm on both client (for crosshair feedback) and server (authoritative
     validation).
   - Minecraft's native entity bounding boxes are reduced to coarse collision
     shells or bypassed.
3. **Bridge Responsibilities**:
   - Bridges do NOT wrap Minecraft model or hitbox APIs.
   - Bridges merely supply input events (player eye position, look vector, attack
     key) and host the OpenGL context/window for GPU-instanced rendering.
4. **No Legacy Monolith**:
   - Algorithms extracted from `matoulib-core` must be cleanly separated:
     mathematics and specifications in `matou-spi`, GL adapters in bridge hooks.

## Gates

- `zero-mc-import` in `matou-spi`: all geometric classes compile with zero
  Minecraft dependencies under `javac --release 8`.
- Parity across bridges: no bridge carries custom or diverging hitbox math.
