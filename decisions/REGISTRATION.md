---
type: spec
status: active
roadmap: -
---

# Registration — real custom ore, bridge-owned generic block

Date: 2026-09-10
Status: active (first consumer: bridge-1710 `Example1Mod` preInit, live-proven 2026-09-10)

## Problem

`example1.content:my_ore` is pure data only (`block my_ore` with
`hardness`/`opaque` in `example1/content/owned.matou`). Zero
`GameRegistry`/`registerBlock` usage exists anywhere in `forge/src` or
`java/src` (measured by grep — the only block resolve on the planet is
`Block.getBlockFromName`). Every live proof to date is 100% vanilla
stone: the wire block arg (`run-live.sh:302` live,
`packs.cfg.example` dist) plus palette aliases
(`ExamplePack` `BLOCK_ALIAS_PREFIX`/`blockAliases`, substituted in
`StructurePlaceJob`) both resolve through the same vanilla path. There
is no custom block to place a vein of, to drop loot from, or to repop.

## Decision

Example1 exposes a pure `BlockSpec` (name, hardness, opaque — parsed
once from `owned.matou` through `MatouParse`, zero MC, same
parse-once pattern as `ExamplePack.fromFiles`); the bridge owns the
only Forge class, a generic `MatouBlock` (extends
`net.minecraft.block.Block`, `Material.rock`, hardness/opacity driven
from the spec — never hardcoded per content).

- Lifecycle: registration belongs in a new
  `preInit(FMLPreInitializationEvent)` in a second mod,
  `Example1Mod.java` under example1's own frozen modid
  (`bridge-1710/forge/src/.../Example1Mod.java:49`, NOT in
  `MatouBridgeMod`, whose init stays bind-only at `:75` with `stone` at
  `:76`). 1.7.10 FML prefixes every `GameRegistry` name with the ACTIVE
  mod container (measured live: registering `example1:my_ore` from
  `matoubridge` lands `matoubridge:example1:my_ore` with an "Illegal
  extra prefix" warning — `GameData.addPrefix` re-prefixes on mismatch),
  so the container owning the `example1:` prefix must be the one
  registering; short name in, container prefix out, zero warnings.
  FML runs every mod's preInit before any init, so the name must exist
  before the Init-time binds resolve it (`PackWire.bind` per spec).
- Resolve path: unchanged. The registered `example1:my_ore` flows
  through the existing calls — `PackWire.java:44`
  (`Block.getBlockFromName(spec.blockName)`) for the wire block and
  `WorldCellSink.java:60` (cached `resolved` map) for volume cells —
  e.g. `packs.cfg`
  `block.<ref>=example1:my_ore`. No second resolve path.
- Parity: 1710-only first, codes `E_REG_*` local in the new
  `Example1Mod.java` (+ `MatouBlock.java`, same package) only (spike
  precedent: `E_SPIKE_*` in the mod file). `tools/check-bridges.sh:28-29`
  diffs only forge basenames and the `E_FORGE_*` catalog, so sibling
  bridges carry same-basename zero-import shells (`MatouBlock.java`,
  `Example1Mod.java` — unwired, documented) and parity holds unchanged;
  other bridges keep compiling as before.
- Stubs/pins: `tools/live/stub/net/minecraft/block/Block.java:16`
  today pins `getBlockFromName` plus the registration surface
  (`run-live.sh:84-94`); the tranche adds stub members plus pins for
  `GameRegistry.registerBlock`,
  `Block/setBlockName`, `Block/setHardness`, `Block/isOpaqueCube`,
  `Block/getIdFromBlock`, `Block.<init>(Material)`,
  `Material/rock`, `Block/opaque` (plus the `pin_uni` entries).
  Hierarchy-aware reobf (`tools/live/Reobf.java` walks the in-jar
  superclass chain): inherited refs compiled with the project owner
  remap to SRG, overriding declarations included — measured live
  (`NoSuchMethodError MatouBlock.setBlockName` before, `func_*`
  after, javap-verified). Unpinned member = loud
  failure, never a silent default.
- Verdict: a custom block gets a dynamic runtime numeric ID, so the
  frozen table (`verify-client-save.sh:84` `NUMERIC_FROZEN`,
  `run-live.sh:349` id table) cannot hardcode it. The server verifier
  resolves the ID dynamically per block name at verify time (preInit…
  init registration line in the boot log) and asserts per-name groups
  instead of one constant; the client verifier keeps the frozen table
  for immutable vanilla IDs plus a `$NUMERIC_IDS` env override for
  future custom-wire client proofs (unset = behaviour unchanged).
  Live-proven 2026-09-10 on Forge 1614: `my_ore` id 165, world == pure
  union (1274 cells, ids 1,165); repop seam re-proven same day
  (`SPIKE=1` direct client: mined tick 1000, repopped 1199, delay
  exactly 200).
- Ports: 1122 repeats the same shape (`GameRegistry`); 1165/1201 use
  `DeferredRegister` — same `BlockSpec` in, native call out. One spec
  per content, one generic class per bridge, never a `Block` subclass
  in `example1` (Q2 zero-MC holds).

Explicit non-goals for tranche 1: metadata/TileEntity restore, one
`Block` subclass per content, second custom block (rides the same path
with no new codes when it comes).

## Gates (will prove the tranche)

- E0 pure green: `BlockSpec` parse + refusals (missing/bad
  hardness, unknown ref — loud, never defaulted), etage 1.
- Live-build replica green without booting: new pins all resolved,
  stub compile with the block linked, no stub leak, reobf jar carries
  the registration.
- Live proof green on Forge 1614: world contains `example1:my_ore`
  cells at the wired positions (dynamic ID resolved per name), the
  rest == pure union, and the repop seam stays green (`SPIKE=1` run).

## What would re-open it

- A second custom block needing its own class: denied by default —
  parameterize the generic block first.
- A submod asking for one MC import for registration: STOP + user
  question (Q2), never a quiet `provided` edge.
