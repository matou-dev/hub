---
type: spec
status: active
maturity: prototype
scope: shared
roadmap: -
---

# Registration — real custom ore, bridge-owned generic block

Date: 2026-09-10
Status: active (first consumer: bridge-1710 `Example1Mod` preInit,
live-proven 2026-09-10; second consumer: bridge-1122 registry-event
`Example1Mod`, live-proven 2026-09-10 — block-only both, no beast;
third/fourth: bridge-1165 + bridge-1201 `DeferredRegister`
`Example1Mod`, live-proven 2026-09-10 — block-only, no beast)

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
  precedent: `E_SPIKE_*` in the mod file).   `tools/check-bridges.sh:39-40`
  diffs only forge basenames and the `E_FORGE_*` catalog, so sibling
  bridges carry same-basename zero-import shells (`MatouBlock.java`,
  `Example1Mod.java` — unwired, documented) and parity holds unchanged;
  other bridges keep compiling as before. Thrown set
  (PORT_QUEUE-declared, `decisions/BRIDGE_PARITY.md`): `E_REG_PACKS` /
  `E_REG_UNRESOLVED` (pack read), `E_REG_BEAST` (beast spec),
  `E_REG_DUP` / `E_REG_SPEC` / `E_REG_NOSPEC` / `E_REG_BLOCK` /
  `E_REG_TABLE` (spec shape); sibling shells throw
  `E_REG_SHELL:unwired` and point here. Block-only ports (no beast
  path, `MatouEntity` stays shelled) narrow the set to the six
  non-beast codes — still cited, still green under dim 4a.
- Ports: 1122 does NOT repeat the 1710 shape — 1.12.2 Forge 2860 has
  no `GameRegistry.registerBlock` (measured: absent from the pinned
  universal by `javap`, the earlier same-shape claim was intent, never
  measured). Version-native 1122: preInit queues validated specs,
  `RegistryEvent.Register<Block>` on the Forge bus registers them
  (`@Mod.EventBusSubscriber`), init verifies + prints the same
  `registered <…> id …` line; live-proven 2026-09-10 on Forge 2860
  (bridge-1122 `49aa98a`, my_ore id 253 dynamic, world == pure union
  1274 cells ids 1,253). 1165/1201 use `DeferredRegister` — same
  `BlockSpec` in, native call out, E0-landed 2026-09-10
  (bridge-1165 `02e29a4`, bridge-1201 `37fb977`), live-proven the same
  day (bridge-1165 `99165d7` on Forge 36.2.42, bridge-1201 `2f3c23b`
  on Forge 47.2.0 — world == pure union 1274 cells, ore + stone names
  on both). Binds on the deferred bridges move to a common-setup
  listener (constructor parses specs pure, setup binds — the fill lands
  one loading state earlier, whatever the mod order). One spec
  per content, one generic class per bridge, never a `Block` subclass
  in `example1` (Q2 zero-MC holds).
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
  exactly 200). Second runtime 2026-09-10 on Forge 2860: `my_ore` id
  253 dynamic, world == pure union (1274 cells, ids 1,253 —
  bridge-1122 `49aa98a`).
- Port rule (measured on 1122, applies to every block-owning bridge):
  same `BlockSpec` in, native call out. One spec per content, one
  generic class per bridge, never a `Block` subclass in `example1`
  (Q2 zero-MC holds).

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

## Port lessons (1122 block-only, 2026-09-10)

Measured porting registration off the lead bridge — each applies to
every block-owning bridge (1165/1201 live tranches clear the same
bars, flagged at their E0, not solved there):

- `GameRegistry` is not a portable shape: 2860 has no
  `registerBlock` (`javap` on the pinned universal). Port from the
  spec (`BlockSpec` in, native call out), never from the 1710 calls;
  an in-repo "same shape" claim is intent until a `javap` confirms
  it.
- Hierarchy-aware reobf ships with the tranche: inherited member refs
  compile with the project class as owner (`MatouBlock.setHardness`
  died `NoSuchMethodError` at the registry event under the old
  owner-blind map). 1710's chain-walking `Reobf.java` ports verbatim;
  sibling copies predate it (1165 confirmed stale, 1201 to verify at
  live time).
- Erased descriptors for generic Forge calls: `javac` emits the
  erasure for inherited generic methods (probed locally:
  `Sub.m:String>Sub` emits `(String)I`, the bound). The stub chain
  must mirror the real generics (`Block extends Impl<Block>`, no
  concrete redeclare) or the call emits an unlinkable reference
  (measured: `Block.setRegistryName(Lnf;)Laow;` against runtime
  `(Lnf;)LIForgeRegistryEntry;`). Forge members need no narrow-map
  row (runtime-final MCP names, `pin_uni` presence only).
- Overrides link through the same walk: `isOpaqueCube` carries the
  spec opacity in a project-side slot (no vanilla slot on 1.12.2),
  its declaration renamed via the superclass chain — the slot splits
  no reader (no vanilla `opaque` member on 1.12.2).
- Descriptor collisions anchor on SRG names: `setHardness` shares its
  descriptor with `setResistance`, every `Material` field shares one
  type — the narrow derive takes an optional 6th `WANT` element (SRG
  anchor from `de.oceanlabs.mcp:mcp_stable:39-1.12`, zip sha1
  `eead02d7aea31dcd0e2080cac702720a0b979a6e`, build-time reference
  only, re-verified from pinned bytes at every run); an anchor
  missing from the bytes fails loud.
- Deferred-bridge bind timing: `MatouBridgeMod` bound at construction
  on 1165/1201, before deferred registries fill — binds moved to a
  common-setup listener on both (constructor parses specs pure, setup
  binds; 1122 binds at init, safe by construction); 1201 pins plus a
  name-based id token (no numeric ids on 1.20.1).

## Live lessons (1165 + 1201 block-only, 2026-09-10)

Measured proving the deferred bridges — each applies to every
modern-registry bridge (1122/1710 unaffected: null-meaning `getValue`
there, noted per call site):

- `getValue` never returns null on modern registries: it answers the
  registry default (air for blocks) for unknown names. A null check
  cries `E_REG_DUP` on a correct config (first 1165 live died loud on
  it) and, worse, resolves typos to air silently. The only presence
  probe is `IForgeRegistry.containsKey` (pinned on both) — applied at
  all three resolve sites (`Example1Mod` DUP check, `PackWire.bind`,
  `WorldCellSink` volume resolve). Same semantics on 1.20.1
  (verified live, preempted before its first boot).
- 1165 needs the hierarchy-aware reobf (verify calls
  `getDefaultState` on the `RegistryObject<MatouBlock>` value — owner
  `MatouBlock`, linked through the superclass chain, same class as
  the 1122 `setHardness` finding); 1201 does not (no project-owner
  vanilla refs — its owner-blind `Reobf` linked clean first try,
  closing the E0 "to verify" flag with a negative answer).
- 1165 descriptor collisions anchor on the SRG name (four
  `hardnessAndResistance` overloads share one descriptor — snapshot
  name filters first, tsrg + javap still confirm, same family as the
  1122 `WANT` anchor).
- javap wildcard generics break the derive parser a third time
  (`ceg$d<aqe<?>>` on 1165, `dca$e<bfn<?>>` on 1201 — the field-type
  class gains `?`; same family as the 1.12-era `FutureTask<?>` fix).
- 1201 `FMLCommonSetupEvent` ships in the universal jar, not fmlcore
  (pinned `pin_uni`, stub comment fixed in the same commit).
- 1165 `getStateId` reads 0 at setup time (state ids assign later) —
  the `registered <…> id …` line stands as a presence token only;
  the verdict keys on names, never on it.

## What would re-open it

- Entity registration (mob twin of this block path): landed under hub
  decisions/SPAWN.md (custom entity tranche — `MatouEntity` +
  `EntityRegistry` + pig-renderer mapping, same second-@Mod shape,
  1710-only with shells).
- A second custom block needing its own class: denied by default —
  parameterize the generic block first.
- A submod asking for one MC import for registration: STOP + user
  question (Q2), never a quiet `provided` edge.
