---
type: ruling
status: active
maturity: unrated
scope: shared
roadmap: -
---

# Live shell common — hub-owned harness steps, thin version wrappers

Date: 2026-09-11
Status: active

## Problem

The eSLOC ceiling (`decisions/EFFECTIVE_SLOC.md`, extended to `*.sh` the
same day) fired on 4 live/client harnesses: `bridge-1201/tools/run-live.sh`
(905 eSLOC), `hub/tools/run-client.sh` (687), `bridge-1165/tools/run-live.sh`
(680), `bridge-1122/tools/run-live.sh` (614). The 4 bridge run-live scripts
share 259-377 byte-identical lines (pin helpers, normjar/mkjar, preflight,
fetch, boot, verdict, anvil loop), and `run-client.sh` mirrors the jar
helpers — every harness fix had to land 4-5 times, drifting silently
(measured the same day: the 1122/1165/1201 world-compare dropped the
outside-union direction the 1710 compare keeps).

## Decision

1. **Single home.** `hub/tools/live-common.sh` (sourced, never executed)
   owns the shared mechanics: `live_init`, `live_preflight_dir`,
   `live_fetch`, `live_install_server`, `live_pin_method/field/uni`,
   `live_normjar/mkjar`, `live_stage_packmcmeta`,
   `live_mod_has_metadata`, `live_boot`, `live_verdict`,
   `live_anvil_loop`, `live_compare_ids/names`. Hub-only splits ride
   beside it (`client-autoplay.sh`, `client-prism.sh`).
2. **Thin wrappers.** Each `bridge-*/tools/run-live.sh` keeps only what is
   version-measured: env defaults, pin rows, narrow-map derive, javac
   lines, R2 assembly, deploy + packs.cfg, plus era-bound one-line
   adapters (`pin_method() { live_pin_method "$SRG_..." "$@"; }` ...) so
   every call site stays byte-identical. Sourcing contract: wrapper `cd`s
   to the bridge root first, refuses a missing `../hub` sibling loudly,
   then `. ../hub/tools/live-common.sh` + `live_init "<tag>-live"`.
3. **Same shim discipline as `run-client.sh`.** Bridge `tools/run-client.sh`
   wrappers already `exec` the hub helper with a sibling-absent loud fail
   (`BRIDGE=... exec sh $HUB/tools/run-client.sh`) — sourcing hub shell
   from a bridge harness is the established pattern, not a new layering
   edge (`decisions/LAYER_Q1_Q11.md` Q11 sibling checkout covers hub; the
   zero-MC gates only watch shipped `forge/` + `java/` code, never tools).
4. **Lib hygiene.** No `$0` except inside human fix hints (there it names
   the executed wrapper — correct). No `cd`, no sibling discovery, no
   caller-owned globals (`BLD/SERV/UNI`) — everything arrives as args in
   `live_`-namespaced locals. `exit` on failure is allowed: callers are
   executed harnesses under `set -eu`, never interactive shells.
5. **No silent strengthening.** Shared extracts stay byte-faithful to the
   strictest donor (1710): the `live_compare_ids` keeps both directions +
   foreign-ID refusal, `live_compare_names` keeps the 1165/1201 shape
   verbatim. The weaker 1122/1165/1201 compare direction is NOT smuggled
   in — unifying on the strict shape is a named follow-up, not this cut.

## Gates

- `sh -n` on every touched + new shell file.
- `hub/tools/check.sh` green (incl. `sloc-self-test` 10 cases).
- `tools/check_sloc.py` full scan: `run-client.sh` 687 -> ~164 eSLOC,
  `live-common.sh` + splits each under ceiling (advisory alert only).
- Per-bridge wrapper proof: bridge `tools/check.sh` stages 1-2 green +
  `BUILD_ONLY=1` dist assembly where the provisioned cache allows; the
  pending live proof then validates the refactored harness (it has not run
  yet, so the refactor invalidates nothing).
- Rollout order: 1710 first (smallest, live-proven — pattern proof), then
  1122/1165/1201 + strict-compare unification as one follow-up tranche.

## What would re-open it

- A fifth bridge: scaffold a thin wrapper from day one (pins + derive),
  never a fifth copy of the shared steps (`tools/scaffold-bridge.sh`
  placeholder should point here).
- A shared step that needs per-version branching beyond args: split the
  function by era (precedent: `pin_game/pin_lib` stayed 1201-local until
  a second consumer exists), never `if SFX` inside the common lib.
