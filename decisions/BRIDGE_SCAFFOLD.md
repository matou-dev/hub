---
type: ruling
status: active
maturity: unrated
scope: bridge
roadmap: -
---

# Bridge scaffolder — green at scaffold, live stays loud-TODO

Date: 2026-09-09 (reconstructed; scaffolder landed in hub `f8f4bdc`,
1201 born in `b646b11`, 1165 opened in `ca4038f`)
Status: active

## Problem

Hand-cloning a bridge to a new Minecraft version copies last year's
workarounds along with the structure: stale mappings, a live script
that only ever ran on the old version, docs claiming a proof that never
happened here. The new bridge looks done before anything on it was
ever proven.

## Decision

`tools/scaffold-bridge.sh:20-70` takes `--sfx --mc --forge` (plus
`--sink modern|legacy`, `--mapping derive|srg`, `--ref` sibling,
`--spi-pin`, `--phase`, `--dry-run/--no-check`) and renders a new
`../bridge-<sfx>/` from `tools/bridge-template/` (`@TOKENS@` via
`:112-137`, leftover-token check `:192-196`, auto `check.sh`
`:201-206`):

- Rendered per version: `MatouBridgeMod.java`, `PackWire.java`,
  `WorldCellSink-<sink>.java` (modern `setBlockState` vs legacy
  `setBlock`), plus the post-B3 parity shells (`Example1Mod.java`,
  `MatouBlock.java`, `MatouEntity.java` — zero-import, declared gap
  pointing at hub `decisions/`, see `BRIDGE_PARITY.md` PORT_QUEUE),
  `tools/check.sh`, `tools/run-live.sh`,
  `tools/live/Dockerfile`, `README.md`, `CHANGELOG.md`, `check.yml`,
  `live-proof.yml`, `SPI_PIN`.
- Copied verbatim: `AGENTS.md`, `.gitignore`, `LICENSE`,
  `ForgeContentCheck.java`, `anvil.py`, `CellUnion.java`,
  `Reobf.java`, `stub/`, `run-client.sh`, `verify-client-save.sh`.
- Dev-client wrappers come along as thin copies from `--ref`
  (`scaffold-bridge.sh:141,174-175,189`); the shared logic stays in
  `hub/tools/client-common.sh:1-12` (see `DEV_CLIENT_SSOT.md`,
  to-write queue).

Green at scaffold means etages 1+2 only
(`bridge-template/check.sh.tpl:3-10,59-60`): etage 1 =
`no-legacy-matoulib` + sibling compile (`../spi`, `../example1`) +
`zero-mc-bridge` + pure E2E `ForgeContentCheck`; etage 2 =
`forge-stub` (compile `forge/` against shape-only
`tools/live/stub/`, no `MC_JAR`). Etage 3 is skipped without `LIVE=1`.
The live script ships as a loud-fail placeholder
(`run-live-placeholder.sh.tpl:25-26`: `FAIL <x>-live : live not wired…
— exit 1`), red under `LIVE=1` or dispatch, never green by accident.
1201 scaffolded D1+D2 green with D3 live TODO; 1165 the same with E3
TODO — both TODOs were then proven live, same 1274-cell verdict.

## Gates

- Fresh scaffold: `tools/check.sh` green at scaffold (etages 1+2),
  live placeholder red under `LIVE=1`.
- `tools/check-bridges.sh` accepts the newcomer from day one (same
  `SPI_PIN`, same file-set, same `E_FORGE_*` catalog, shells pointed
  at hub decisions, no uncited local code).

## What would re-open it

- A version needing a third sink shape: new
  `WorldCellSink-<shape>.java.tpl` + `--sink` value, never a
  hand-edited sink post-scaffold.
- Etage-2 stub drift (shape no longer mirrors the real Forge):
  found live so far (D3/E3 notes) — a second occurrence earns the
  stub its own derivation gate.
