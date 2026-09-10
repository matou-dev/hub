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

`hub/tools/check-bridges.sh:5-46` enforces three parity dimensions over
every `../bridge-*/` sibling, and refuses loud on any of them:

1. `SPI_PIN` — all bridges pin the same validated SPI
   (today `00934e1fc84317725cf478fea3d5380c8075e76b`). The laggard
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

What parity deliberately tolerates: same behaviour through native APIs.
`1710/MatouBridgeMod.java:60` checks `provider.dimensionId!=0` where
`1165` checks `World.OVERWORLD.equals(getDimensionKey())` and `1122`
checks `provider.getDimension()!=0`; 1710 registers on
`FMLCommonHandler.instance().bus()` where 1165 uses
`MinecraftForge.EVENT_BUS` (`1165/MatouBridgeMod.java:37`); the 1710
sink calls `setBlock(x,y,z,block)` where 1201 builds a `BlockState`
(`1201/WorldCellSink.java:10,58-59`). Same verdicts, version-native
spelling — the E2E proves it, not the diff.

Mapping inputs are derived live, never pinned: 1122 derives a narrow
MCP→SRG map in-run (`joined.tsrg`+`javap`, no `srg-mcp.srg`;
`bridge-1122/README.md:73-75`); 1201 keeps official Mojmap classes and
reobfs members only (`bridge-1201/README.md:49-50,57`); 1165 locks the
MCP snapshot name (`mcp_snapshot-20210309`;
`bridge-1165/README.md:50-51`). No mapping file in the repos can rot.

## Gates

- `tools/check-bridges.sh` green: pin + file-set + error catalog over
  all bridges (no sibling = loud skip, never silent red).
- Parity holds over 4 bridges (`STATE.md:84-85`); every live proof
  reports the same 1274-cell world == pure union count.

## What would re-open it

- A fifth bridge: same three dimensions from its scaffold commit.
- A sixth `E_FORGE_*` code: land it in all four bridges in one round,
  or the gate says which one forgot.
