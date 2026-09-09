---
type: ruling
status: active
roadmap: -
---

# Launcher-free automated client proof — plain java under xvfb

Date: 2026-09-09 (landed as hub `fb1e600` with no decision file —
catch-up owed, same class as `a3097de`)
Status: active

## Problem

The Prism path (`run-client.sh`: accounts, Qt, wizard, manual world
creation) cannot prove a client automatically: headless runs leaked a
window onto the real session once already (`HEADLESS_XVFB_QT_XCB.md`),
and no gate can click through a launcher. Client proof stayed manual
while every server proof was automated and verdict-owned.

## Decision

`hub/tools/run-client-direct.sh:1-279` (DEV ONLY, NOT a gate) plays
the staged instance with no launcher: the official Forge installer
provisions the client runtime once (cached), then plain java replays
the production ModLauncher invocation headless under `xvfb-run`. No
Prism process ever runs here — no accounts, no Qt, no Wayland leak by
construction. Flow is two commands, zero duplicated staging:
`AUTOPLAY=1 … run-client.sh` stages DEV jars + content + packs.cfg and
preseeds a fresh world (`run-client-direct.sh:11-16`), then
`run-client-direct.sh` provisions, plays, and replays the verdict.

1165-only guard (`run-client-direct.sh:37-40`): any other `SFX` fails
loud with "no measured client pins (only 1165; provision once, pin,
extend the table below)". Measured pins, never silent upgrades:
vanilla json URL + SHA1 (`run-client-direct.sh:49-50`), installer
`INSTALLER_SHA1` reused from the bridge `run-live.sh`
(`run-client-direct.sh:61-69`), assets sha1-addressed missing-only
(`run-client-direct.sh:98-126`), libraries fetched from pinned json
entries with sha1 check (`run-client-direct.sh:155-172`), Forge-first
classpath dedup on group:artifact conflicts
(`run-client-direct.sh:173-187`), unknown `${placeholder}` = loud
(`run-client-direct.sh:227-231`). CWD is the game dir: the bridge
reads `config/matoubridge/packs.cfg` RELATIVE, Q1-passive
(`run-client-direct.sh:263-269`). `WAYLAND_DISPLAY` is unset before
play; `VERIFY=0` skips the verdict, default replays
`verify-client-save.sh` and the verdict owns the exit status
(`run-client-direct.sh:271-279`).

Found through this path (measured, not assumed): autoplay derive
SRG-slot fix (Reobf maps MCP->LEFT, `run-client.sh:314-316`),
WorldGenSettings preseed (bridge-1165 `4c08403`, legacy generator
tags ignored on 1.16.5), Qt-xcb pin under XVFB, game-dir CWD.

## Gates

- Green run (1165): world == pure union (1274 cells, stone only —
  same count as every live proof).
- `tools/check.sh` green; other versions stay refused until provisioned
  and pinned per version.

## What would re-open it

- A second version: provision once, pin its vanilla json + installer +
  ASM row, extend the `case SFX` table — never widen the guard silently.
- Prism stays the manual-dev convenience; automation never grows a
  launcher dependency back.
