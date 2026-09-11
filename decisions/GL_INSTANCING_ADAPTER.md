---
type: spec
status: active
maturity: prototype
scope: shared
roadmap: -
---

# GL Instancing Adapter — unified cross-version GPU instancing

Date: 2026-09-11
Status: active

## Problem

Rendering hundreds of custom animated entities through Minecraft's native
immediate or tessellator pipelines causes severe CPU draw-call bottlenecks and
inherits version-specific render overhauls across 1.7.10, 1.12.2, 1.16.5, and
1.20.1.

While the geometric planning half ([`decisions/GPU_INSTANCING.md`](GPU_INSTANCING.md):
`Frustum` and `InstanceBucket`) is proven pure in `matou-spi`, bridging to actual
driver execution requires isolating the 3 version-specific parameters:
1. LWJGL 2 (`org.lwjgl.opengl`) on 1.7.10 / 1.12.2 vs. LWJGL 3 (`org.lwjgl.opengl.*C`) on 1.16.5 / 1.20.1.
2. Minecraft's OpenGL context: Compatibility Profile (1.7/1.12) vs. Core Profile 3.2 (1.20.1).
3. End-of-frame render event: `RenderWorldLastEvent` (1.7/1.12/1.16) vs. `RenderLevelStageEvent` (1.20.1).

## Decision

The instancing engine adopts a **two-tier architecture**:

### 1. Pure Contract & Planning Layer (`matou-spi`)

- **`GlBackend`**: A pure Java 8 interface defining the minimal OpenGL 3.1+ instancing primitives:
  - Buffer management: `genBuffers`, `bindBuffer`, `bufferData`, `deleteBuffers`.
  - Vertex attribute arrays: `enableVertexAttribArray`, `vertexAttribPointer`, `vertexAttribDivisor`.
  - Shader & program pipeline: `createShader`, `shaderSource`, `compileShader`, `createProgram`, `attachShader`, `linkProgram`, `useProgram`.
  - Draw command: `drawArraysInstanced(int mode, int first, int count, int instanceCount)`.
  - Uses standard Java types (`int`, `java.nio.FloatBuffer`, `java.nio.ByteBuffer`), zero LWJGL/MC imports.
- **`InstanceFormat`**: Defines the packed layout of per-instance data:
  - 12 floats per instance: `posX, posY, posZ`, `yaw, pitch, scale`, `r, g, b, a`, `lightU, lightV`.
  - Validates coordinates and protects against NaN leakage (`E_INSTANCE_DATA:nan`).
- **`Frustum` & `InstanceBucket`**: Camera culling and model/texture batching (already active).

### 2. Bridge Driver Layer (`bridge-*`)

- **LWJGL 2 Driver (`Lwjgl2Backend`)**:
  - Implements `GlBackend` via LWJGL 2 bindings (`GL11`, `GL15`, `GL20`, `GL31`).
  - Shared design between `bridge-1710` and `bridge-1122`.
- **LWJGL 3 Driver (`Lwjgl3Backend`)**:
  - Implements `GlBackend` via LWJGL 3 bindings (`GL11C`, `GL15C`, `GL20C`, `GL31C`).
  - Shared design between `bridge-1165` and `bridge-1201`.
- **Event Hooks**:
  - `bridge-1710` & `bridge-1122`: `RenderWorldLastEvent`.
  - `bridge-1165`: `RenderWorldLastEvent`.
  - `bridge-1201`: `RenderLevelStageEvent.Stage.AFTER_ENTITIES`.

### 3. Core Profile OpenGL 3.1+ Compatibility

By targeting modern OpenGL 3.1+ instancing primitives (VAO, VBO, vertex shaders)
rather than legacy immediate mode or display lists:
- The exact same shader and buffer logic executes on modern 1.20.1 Core Profile.
- The exact same shader and buffer logic executes backward-compatibly on 1.7.10 and 1.12.2.

### 4. Error Catalog (`E_GL_*`, `E_INSTANCE_*`)

- `E_GL_BUFFER:null`: Null buffer passed to backend.
- `E_GL_BUFFER:overflow`: Instance buffer capacity exceeded.
- `E_GL_SHADER:compile`: Shader compilation failed.
- `E_GL_PROGRAM:link`: Program linking failed.
- `E_INSTANCE_DATA:nan`: Instance transform or lightmap value is NaN.
- `E_INSTANCE_DATA:shape`: Invalid packing array dimensions.

## Gates

- `spi/tools/check.sh` green:
  - `zero-mc-import` passes.
  - `GlBackendCheck` unit test verifies instance packing fidelity and mock backend call sequence.
- Parity maintained:
  - Bridge parity gate `tools/check-bridges.sh` remains green with uniform pins and declared error codes.
