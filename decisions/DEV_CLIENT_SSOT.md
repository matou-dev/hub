---
type: ruling
status: active
maturity: unrated
scope: client
roadmap: -
---

# Dev-client SSOT — hub owns logic, bridges own thin wrappers

Date: 2026-09-09 (generalized from bridge-1165, wrappers landed on all 4 bridges)
Status: active

## Problem

Dev-client staging lived inside bridge-1165: the next bridge would
re-derive provisioning truth, per-version parameters and the play
protocol by hand, drifting silently (wrong ASM, slim jar where FAT is
required, clobbered alias bindings). Provisioning truth already belongs
to each bridge `tools/run-live.sh`; a second copy in client tooling is
a dated divergence.

## Decision

SSOT is `hub/tools/run-client.sh` (orchestration: resolve, DEV build,
play protocol) + `hub/tools/client-autoplay.sh` (AUTOPLAY=1 companion) +
`hub/tools/client-prism.sh` (instance staging) on `hub/tools/live-common.sh`
mechanics (jar/pack helpers, `decisions/LIVE_SHELL_COMMON.md`) +
`hub/tools/verify-client-save.sh:1-103`, per-version table
`hub/tools/client-common.sh:1-86` (sourced, never executed). Each bridge
carries only thin exec shims
(`bridge-*/tools/run-client.sh:1-12`, same for
`verify-client-save.sh`): set `BRIDGE`, exec the hub file, no logic.
`scaffold-bridge.sh:142,167-168,183` copies the shims to future bridges.

The table carries exactly what cannot be derived
(`client-common.sh:52-72`): `SFX | MC | FORGE_COMP | LIVE_TAG |
JAVA_MAJOR | SRG_DEFAULT | ASM_PIN | NOTE`. Everything else derives:
`MODS_STYLE` from `forge/src/META-INF/mods.toml` presence, `FAT` from
`MODS_STYLE` (`run-client.sh:136-139`, mods.toml era isolates every
mods/ jar — slim dies with NoClassDefFoundError, found live in D3 then
E3), `ASM` from the provisioned live dir with a loud pin check against
`tools/run-live.sh` (`run-client.sh:122-127`), `SRG` from
`$LIVE_DIR/srg-narrow.srg` falling back to `SRG_MCP`
(`run-client.sh:112-121`). `FAT=0|1` overrides a future bridge loudly,
never silently. Row status is explicit: all four direct rows PROVEN
(`client-common.sh:59-78`); Prism path stays UNTESTED for 1201 only
(`client-common.sh:73`).

Build mirrors the bridge pipeline (`run-client.sh:148-225` via the
`live_mkjar/normjar` adapters): same
javac level, normjar EPOCH clamp, stub-leak refusal (`net/cpw` never
ships), FAT embeds spi+example1, reobf via the live narrow map,
`CellUnion` kept compiled so the verifier never duplicates union
logic. `packs.cfg` is written once then kept
(`client-prism.sh:103-110`): re-staging never clobbers a dev's alias
bindings back to stone defaults. `AUTOPLAY=1` stages the DEV-only
companion (`client-autoplay.sh` whole file): narrow map derived from the
pinned vanilla client jar + joined.tsrg, LEFT slot is SRG
(`client-autoplay.sh:289`, Mojmap era), snapshot lock + universal-pin check, then
`preseed.py` resets a fresh flat world (`client-prism.sh:122-128`).
`verify-client-save.sh:42-102` replays the server verdict (same
`anvil.py`, same 1274-cell geometry, expected blocks read from
`packs.cfg` itself). `AUTOVERIFY=1` makes the verdict own the exit
status; `XVFB=1` implies `LAUNCH=1` with Qt pinned to xcb
(`run-client.sh:254-267`, pairs with `HEADLESS_XVFB_QT_XCB.md`). The
live Prism home is refused loudly (`run-client.sh:91-95`).

## Gates

- Equivalence proven for 1165: generalized staging builds
  byte-identical jars to the moved script (same EPOCH,
  normjar-clamped).
- `tools/check.sh` green; untested rows stay labelled, never claimed.

## What would re-open it

- A new bridge row: copy the 1165 row, adjust MC/FORGE_COMP/LIVE_TAG/
  JAVA_MAJOR/ASM_PIN (`client-common.sh:70-71`).
- A future era breaking the FAT correlation: `FAT=` override loudly,
  never a silent default change.
- Different proof geometry: parameterize the verifier explicitly
  (`verify-client-save.sh:11-15`), never widen silently.
