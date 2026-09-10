---
type: spec
status: direction
roadmap: -
---

# Registration — real custom ore, bridge-owned generic block

Date: 2026-09-10
Status: direction (contract frozen, code TODO)

## Problem

`example1.content:my_ore` is pure data only (`block my_ore` with
`hardness`/`opaque` in `example1/content/owned.matou`). Zero
`GameRegistry`/`registerBlock` usage exists anywhere in `forge/src` or
`java/src` (measured by grep — the only block resolve on the planet is
`Block.getBlockFromName`). Every live proof to date is 100% vanilla
stone: the wire block arg (`run-live.sh:289` live,
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
  `preInit(FMLPreInitializationEvent)` in `MatouBridgeMod.java` (today
  only `init(FMLInitializationEvent)` at `:69`, no PreInit). FML runs
  PreInit before Init, so the name must exist before the Init-time
  binds resolve it (`stone` at `:70`, `PackWire.bind` per spec).
- Resolve path: unchanged. The registered `example1:my_ore` flows
  through the existing calls — `PackWire.java:44`
  (`Block.getBlockFromName(spec.blockName)`) for the wire block and
  `WorldCellSink.java:60` (cached `resolved` map) for volume cells —
  e.g. `packs.cfg`
  `block.<ref>=example1:my_ore`. No second resolve path.
- Parity: 1710-only first, codes `E_REG_*` local in the existing
  `MatouBridgeMod.java` only (spike precedent: `E_SPIKE_*` in the same
  file). `tools/check-bridges.sh:28-29` diffs only forge basenames and
  the `E_FORGE_*` catalog, so parity holds unchanged; other bridges
  keep compiling as before.
- Stubs/pins: `tools/live/stub/net/minecraft/block/Block.java:9`
  today pins only `getBlockFromName` (`run-live.sh:82-86`); the tranche
  adds stub members plus pins for `GameRegistry.registerBlock`,
  `Block/setBlockName`, `Block/setHardness`, `Block.<init>(Material)`,
  `Material/rock` (plus the `pin_uni` entry). Unpinned member = loud
  failure, never a silent default.
- Verdict: a custom block gets a dynamic runtime numeric ID, so the
  frozen table (`verify-client-save.sh:80` `NUMERIC_FROZEN`,
  `run-live.sh:355` stone-only set) cannot hardcode it. The verifier
  resolves the ID dynamically per block name at verify time (registry
  or level dump) and asserts per-name groups instead of one constant.
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
