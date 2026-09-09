---
type: ruling
status: active
roadmap: -
---

# Headless XVFB forces Qt to xcb, drops Wayland

Date: 2026-09-09
Status: active

## Problem

Headless dev-client runs under `xvfb-run` still leaked a window onto the
real session: Qt prefers Wayland whenever `WAYLAND_DISPLAY` leaks into the
environment, so a virgin Prism launcher popped onto the operator's actual
screen — looking exactly like wiped accounts. The failure was silent (no
log, no gate) and alarming. Landed as commit `a3097de` with no decision
file — this record is the catch-up, written the same day under
`DOCS_DEFINITION_OF_DONE.md`.

## Decision

In `tools/run-client.sh`, `XVFB=1` now pins `QT_QPA_PLATFORM=xcb` and
unsets `WAYLAND_DISPLAY` before implying `LAUNCH=1`. Headless means
headless: the client can only ever render on the Xvfb display. Missing
`xvfb-run` still fails loud (`FAIL run-client : xvfb-run absent`), never
a silent fallback to the real screen.

## Gates

- `tools/check.sh` green (decisions-parity covers this file).
- Manual headless run leaves no window on the real session.

## What would re-open it

- A second toolkit with its own backend preference (Electron, SDL):
  same treatment at the same use site, never a global export.
- Wayland-only host with no Xvfb: dedicated tranche, not a quiet
  removal of the pin.
