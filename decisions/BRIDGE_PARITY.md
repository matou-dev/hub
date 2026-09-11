---
type: ruling
status: active
maturity: unrated
scope: bridge
roadmap: -
---

# Bridge parity — one pin, one file-set, one error catalog

Date: 2026-09-09 (reconstructed; gate landed in hub `59ded60`)
Status: active

## Problem

Four bridges evolve in four repos. Without a comparator, bridge A gains
a loud refusal that bridge B never learns, bridge C pins next month's
SPI while bridge D still proves last month's — and every live proof
goes stale in a different way. The failure mode is silent divergence
disguised as four green gates.

## Decision

`hub/tools/check-bridges.sh` (dims 1-3 `:34-66`, dim 4 `:67-123`)
enforces four parity dimensions over
every `../bridge-*/` sibling, and refuses loud on any of them:

1. `SPI_PIN` — all bridges pin the same validated SPI
   (today `0ace6885b450ae4807ba14b3a79c6fce68ae031d`). The laggard
   re-validates, then bumps its pin. No bridge ever floats.
2. Forge file-set — `find forge/src -name '*.java' | sed 's|.*/||' |
   sort` must be byte-identical everywhere (today exactly
   `MatouBridgeMod.java PackWire.java WorldCellSink.java`; deployment
   descriptors like `1165/forge/src/META-INF/mods.toml` are out of the
   gate's scope). A file added on one side only is a forgotten
   report, not an optimization.
3. `E_FORGE_*` catalog — `rg -o 'E_FORGE_[A-Z_]+' forge/src | sort -u`
   must match everywhere (today 5 codes: `BLOCK,PACKS,WIRE,WORLD,Y`;
   e.g. `bridge-1710/.../PackWire.java:34 E_FORGE_WIRE:null spec`,
   `:41 E_FORGE_PACKS:args rejected`, `:46 E_FORGE_BLOCK:unknown`,
   `WorldCellSink.java:44 E_FORGE_Y:range`,
   `MatouBridgeMod.java:46 E_FORGE_PACKS:unreadable`). A noisy path
   added on one side must exist on all sides.
4. Declared gap only (PORT_QUEUE below): the full `E_*` catalog over
   `forge/src` + `java/src` (shipped code, never `tools/`) — a code
   missing in any bridge must be cited in hub `decisions/*.md` (the
   tranche that introduced it, thrown set named there); shells (files
   containing `parity shell`) must cite a `decisions/<FILE>.md` on
   disk. The gate prints the per-bridge gap (`shells=` plus
   `local-codes=` — today 1710 leads with 18 local codes and 0
   shells, each sibling owes 1 shell with 1 local code) : the metric shrinks tranche
   by tranche, never silently. An uncited local code or an unpointed
   shell is a forgotten port, not an optimization.

What parity deliberately tolerates: same behaviour through native APIs.
`1710/MatouBridgeMod.java:60` checks `provider.dimensionId!=0` where
`1165` checks `World.OVERWORLD.equals(getDimensionKey())` and `1122`
checks `provider.getDimension()!=0`; 1710 registers on
`FMLCommonHandler.instance().bus()` where 1165 uses
`MinecraftForge.EVENT_BUS` (`1165/MatouBridgeMod.java:37`); the 1710
sink calls `setBlock(x,y,z,block)` where 1201 builds a `BlockState`
(`1201/WorldCellSink.java:10,58-59`). Same verdicts, version-native
spelling — the E2E proves it, not the diff. The GL backend file is the
one era-native basename: `Lwjgl2Backend.java` on LWJGL2 bridges
(1710/1122), `Lwjgl3Backend.java` on LWJGL3 bridges (1165/1201) — same
`GlBackend` contract, era-native bindings (`GL_INSTANCING_ADAPTER.md`);
`tools/check-bridges.sh` normalizes exactly that alternation (any third
spelling, add or remove still fails).

Mapping inputs are derived live, never pinned: 1122 derives a narrow
MCP→SRG map in-run (`joined.tsrg`+`javap`, no `srg-mcp.srg`;
`bridge-1122/README.md:73-75`); 1201 keeps official Mojmap classes and
reobfs members only (`bridge-1201/README.md:49-50,57`); 1165 locks the
MCP snapshot name (`mcp_snapshot-20210309`;
`bridge-1165/README.md:50-51`). No mapping file in the repos can rot.

## PORT_QUEUE (hand-kept — a port tranche flips its cells live in the same commit)

`live` = version-native code live-proven on that bridge ; `shell` =
same-basename zero-import shell pointing at the decision ; `e0` =
version-native code E0-green, live proof TODO (a port tranche may land
E0 and live separately — the cell says which) ; `TODO` =
not ported (no shell stands in — the files match by basename only).
A cell flips to `live` with the version-native live proof alone,
never with the code copy.

| Tranche (decision) | 1710 | 1122 | 1165 | 1201 |
|---|---|---|---|---|
| Registration block+beast, `E_REG_*` (`REGISTRATION.md`) | live | live (block-only) | live (block-only) | live (block-only) |
| Custom entity `MatouEntity` (`SPAWN.md`) | live | live | live | live |
| Vein wire (`VEIN_V4.md`) | live | live | live | live |
| Loot seam+wire, `E_LOOT_*` (`LOOT.md`) | live | live | live | live |
| Spawn seam+wire+hp+override, `E_SPAWN_*` (`SPAWN.md`) | live | live | live | live |
| Vocabulary seals, T3 (`SPI_STATE_VOCABULARY.md`) | live | live | live | live |
| Repop hook+seal, `E_SPIKE_*` (`REPOP_SPIKE.md`) | live | live | live | live |
| Pack-driven loot/spawn policy, T4 (`SPI_STATE_VOCABULARY.md`) | live | live | live | live |
| Item registration MatouItem, `E_REG_ITEM` (`ITEM_REGISTRATION.md`) | live | live | live | live |
| GL Instancing Renderer (`GL_INSTANCING_ADAPTER.md`) | live | live | live | live |
| Beast model mesh+hitboxes (`MATOU_MODEL.md`) | live | live | live | live |

## Gates

- `tools/check-bridges.sh` green: pin + file-set + error catalog over
  all bridges (no sibling = loud skip, never silent red) ; full `E_*`
  catalog declared in hub decisions, all shells pointed, gap printed.
- Lead-bridge advance is bounded by the queue above : every live proof
  on the lead bridge names the unported siblings, and the next port
  tranche starts from the queue row, never from a diff rediscovery.

## What would re-open it

- A fifth bridge: same four dimensions from its scaffold commit
  (the scaffolder renders the shells, the queue gains its column).
- A sixth `E_FORGE_*` code: land it in all four bridges in one round,
  or the gate says which one forgot.
- A new tranche-local code cited nowhere: the gate names it before
  the tranche lands, never after.
