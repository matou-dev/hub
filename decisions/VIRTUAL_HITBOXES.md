---
type: spec
status: active
maturity: prototype
scope: spi
roadmap: -
---

# Virtual Hitboxes — pure geometry ray-testing and authoritative validation

Date: 2026-09-11
Status: active

## Problem

In Minecraft vanilla, combat hit detection is coupled to a single coarse bounding box
per entity, with asymmetric client/server resolution (the client raycasts against interpolated
positions and sends only the target entity ID; the server merely validates that
`distance(player, entity) < maxReach`). This causes two critical failure modes:
1. **No Part/Bone Granularity**: Cannot target specific limbs, head weakspots, or armored zones.
2. **BUG-042 (Large Entity Melee Failure)**: For large entities whose origin is far from their
   outer extremities, the vanilla origin-distance check rejects legitimate hits on the limbs or wings.

## Decision

Virtual Hitboxes decouple hit resolution into a pure geometric ray-box intersection
pipeline located in `matou-spi` (`fr.iamacat.spi.hit`), completely free of Minecraft
and OpenGL imports.

### 1. Data Structures (`fr.iamacat.spi.hit`)

- **`Vec3d`**: Immutable double-precision 3-vector (`x, y, z`) providing vector operations:
  `add`, `sub`, `scale`, `dot`, `lengthSquared`, `length`, `normalize`.
- **`AABBd`**: Immutable double-precision axis-aligned bounding box defined by
  `[minX, minY, minZ]` to `[maxX, maxY, maxZ]`.
  - `intersect(ox, oy, oz, dx, dy, dz, maxDist)`: Evaluates ray-box intersection via the
    Kay-Kajiya slab method. Returns entry scalar $t \ge 0$ (or $0.0$ if the ray origin is
    inside the box) within $[0, \text{maxDist}]$, or `Double.NaN` if no intersection occurs.
  - Rejects degenerate coordinates (`min > max`) or NaN components with `E_HIT_BOX:degenerate`
    and `E_HIT_BOX:nan`.
- **`BoneBox`**: Associates a logical bone identifier (`boneName`) with an `AABBd`.
- **`RayHit`**: Immutable result of a successful ray intersection:
  - `boneName`: Name of the struck bone.
  - `hitVec`: Exact world-space point of intersection (`Vec3d`).
  - `distance`: True world distance from ray origin to `hitVec`.
- **`Hittable`**: Pure SPI interface implemented by targets:
  - `List<BoneBox> hitBoxes()`: Returns the collection of active bone bounding boxes.
  - `Map<String, Float> hitWeakspots()`: Returns damage multipliers per bone (e.g. `"head" -> 2.0F`).
  - `float weakspotMultiplier(String boneName)`: Resolves damage multiplier (default `1.0F`).

### 2. Algorithmic Ray Testing (`HitTester`)

`HitTester.test(List<BoneBox> boxes, Vec3d origin, Vec3d dir, double maxDist)`:
1. Validates inputs: rejects null/NaN origins, zero-length or NaN direction vectors, and negative reach.
2. Normalizes `dir` to guarantee that the returned parameter $t$ equals Euclidean world distance.
3. Tests ray against each `BoneBox` in the collection.
4. Selects the minimum $t \ge 0$ across all candidate boxes.
5. Computes exact impact position $\mathbf{p} = \text{origin} + t \cdot \text{dir}$.
6. Returns `RayHit(bestBone, p, minT)` or `null` if no boxes intersect within `maxDist`.

### 3. Client/Server Authoritative Validation Lifecycle

1. **Client-Side (Prediction & Feedback)**:
   - Player triggers attack.
   - Client executes `HitTester.test(target, eyePos, lookVec, reach)`.
   - On hit: client displays instantaneous visual/crosshair feedback and sends an attack packet
     containing `(entityId, boneName, hitVec, distance)`.
2. **Server-Side (Authoritative Validation)**:
   - Server receives packet.
   - Server verifies player reach and line of sight.
   - Server evaluates the **identical** pure function:
     `HitTester.test(target, serverEyePos, serverLookVec, serverMaxReach)`.
   - If the server calculation confirms that `boneName` was hit within spatial tolerance,
     the hit is approved and `weakspotMultiplier(boneName)` is factored into damage calculation.
   - If the ray misses or targets an unhit bone, the hit is rejected without applying damage.

### 4. Error Catalog (`E_HIT_*`)

- `E_HIT_ORIGIN:nan`: Ray origin coordinates contain NaN.
- `E_HIT_ORIGIN:null`: Ray origin vector is null.
- `E_HIT_DIR:zero`: Ray direction vector has zero length.
- `E_HIT_DIR:nan`: Ray direction vector contains NaN.
- `E_HIT_DIR:null`: Ray direction vector is null.
- `E_HIT_DIST:negative`: Maximum reach distance is negative.
- `E_HIT_DIST:nan`: Maximum reach distance is NaN.
- `E_HIT_BOX:degenerate`: AABB min bounds exceed max bounds.
- `E_HIT_BOX:nan`: AABB bounds contain NaN.
- `E_HIT_TARGET:null`: Target hittable or bone box list is null.

## Gates

- `spi/tools/check.sh` green:
  - `zero-mc-import` passes.
  - `javac --release 8` compiles `fr.iamacat.spi.hit.*` without errors.
  - Test suite `HitCheck` passes with comprehensive coverage:
    - Ray-AABB intersection goldens (center hit, corner hit, miss, ray origin inside box).
    - Ray parallel to slab planes (inside vs outside slab).
    - Multi-bone ordering: closer bone occlusion over farther bones.
    - Input rejection for all `E_HIT_*` error codes.
    - Weakspot damage calculation.
