---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# Fast dev loop — pure seconds by default, live only on explicit flags

Date: 2026-09-09
Status: active

## Problem

Every mod edit was reaching for the 150s server proof (plus provision
cache misses plus the ~4-10min client run): "1h per feature". The live
proofs are verdict-owned and must stay full-length (short `BOOT_SECS`
fails coverage loudly by bridge design —
`bridge-1710/tools/run-live.sh:17`), so the fix is not a shorter live
run but a layered loop: iterate on the pure gates (seconds), pay for
live only after green, and only the etage the change can affect.

## Decision

`hub/tools/dev-loop.sh:1-67` (DEV ONLY, NOT a gate) orders the existing
scripts fail-fast and re-derives nothing:

- E0 pure (default, seconds): `hub/tools/check.sh:19-22` (hub + parity)
  then `bridge-*/tools/check.sh:59-62` with `LIVE` explicitly cleared —
  pure even if the caller exported `LIVE=1` (said loudly in the note).
- E1 `--server` (minutes): E0 green first, then `LIVE=1` bridge check
  (the 150s server proof; `BOOT_SECS`/`B3_OFFLINE`/`JAVA8_HOME` pass
  through untouched — the bridge owns coverage).
- E2 `--client` (minutes): E0 green first, then the documented
  two-command direct flow (`run-client-direct.sh:13-18`):
  `AUTOPLAY=1 run-client.sh` staging +
  `run-client-direct.sh` launcher-free play + verdict
  (`PRISM_DIR`/`AUTOPLAY_WORLD`/`VERIFY`/`GAME_TIMEOUT` pass through;
  defaults agree by construction). Needs one prior server provision —
  absent bytes fail loudly in the callee with the fix, never here.
- `--offline` exports `B3_OFFLINE=1` (reuse provision cache, never
  download). `BRIDGE`/`--bridge` follows the `run-client.sh:25-26`
  convention (auto-detect only when exactly one sibling resolves,
  ambiguous = loud). Unknown args fail loud (`dev-loop.sh:43`).

Rule of thumb: a content/job change iterates on E0 (goldens +
`ForgeContentCheck` fake-world E2E, seconds); a bind/ASM/reobf change
pays E1; a join/tick-clock/staging change pays E2. Live stays
verdict-owned (`LIVE_PROOF_MODEL.md`, `DIRECT_CLIENT_PROOF.md`); this
loop only decides WHEN to pay for it.

## Gates

- `tools/dev-loop.sh --bridge ../bridge-1710` green (E0: hub check +
  bridge etages 1+2 pure).
- `tools/check.sh` green (index lists this file, parity holds).

## What would re-open it

- A new etage (e.g. a fast single-chunk live slice if the bridge ever
  owns a short-coverage rule): extend the order here, never a second
  loop script.
- A new bridge row: nothing to change (bridge path is a parameter).
