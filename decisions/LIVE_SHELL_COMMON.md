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

## Addendum — strict-compare unification landed, derive stays the ceiling driver (2026-09-11)

Measured before the 1122/1165/1201 rollout (three parallel codebase
surveys, same day): thin-wrapper replacement of the generic mechanics
(`live_preflight/fetch/install`, pin adapters, `live_mkjar/normjar`,
`live_boot/verdict/anvil/compare`) saves only ~140-260 eSLOC per
wrapper. The floor is version-measured and must stay local per rule 2:
1122 narrow-derive 219 lines + coverage 101, 1165 derive 176 + map-cover
99, 1201 derive 405 + build 235. Post-replace estimates: 1122 ~470,
1165 ~440 (borderline), 1201 ~700 — the 1710 shape (360 raw / 232
eSLOC) is unreachable by mechanics extraction alone.

1. **Strict compare is landed now (this cut).** `live_compare_names`
   gains the `world cells outside pure union` direction, same position
   (after mismatch, before missing) and same message shape as
   `live_compare_ids` — both functions now carry foreign + mismatch +
   outside + missing. Proven by fixture, not by re-reading: ok pair
   prints `world == pure union`, extra cell fails loud (via mismatch
   today, outside stands as defense-in-depth in the same order the
   1710 donor uses), missing cell fails `pure cells missing`. The
   1122 inline ids compare (missing only) inherits the strict shape
   automatically when it switches to `live_compare_ids` in the
   rollout — no silent strengthening was smuggled in before.
2. **Derive extraction is the named next cut (table-driven, era-split,
   not this cut).** Narrow-map derive shares one skeleton (fetch maps
   → parse `joined.tsrg` → WANT table → per-row obf resolve + javap
   static check → emit MD/FD → count assert) with three era-bound
   locks: 1122 MCP-config-only 42 rows (anchor pattern), 1165
   MCP-config + snapshot (`methods/fields.csv` lock) 48 rows
   (OVERWORLD disambiguation), 1201 Mojmaps server+client +
   `joined.tsrg` + dual-javap triple-lock 48 rows (+ SAM skip-javap
   rows, inner-jar extraction). Per the rule below (never `if SFX`
   in the common lib) the extraction splits by era — one function
   per lock shape, WANT rows staying version-measured tables in the
   wrappers — never a branching mega-function. Map-cover
   (`E_MAP_COVER`) walks ride the same split (ALLOW set stays local).
3. **Ceiling stays advisory until the derive cut lands**
   (`decisions/EFFECTIVE_SLOC.md` semantics, exit 0). Splitting a
   wrapper into sourced satellites to dodge the per-file count is
   refused (`AGENTS.md` §3 — never split satellite).

## Addendum — derive cut landed, all wrappers under ceiling (2026-09-11)

`hub/tools/live-derive.sh` (432 eSLOC, under ceiling) owns the three
era mechanics verbatim — `live_derive_mcp_anchor` (1.12),
`live_derive_mcp_snapshot` (1.16), `live_derive_mojmaps` (1.20) — with
WANT rows as wrapper-owned TSV tables (`bridge-*/tools/live/want.tsv`,
tab-separated, order-sensitive = emit order). Deltas vs the donors are
exactly two per function: WANT source (inline literal → TSV, same tuple
semantics) and the ok-print tag (hardcoded → argv from `$LIVE_TAG`).
The 1165 snapshot-confirm print generalizes to `%d/%d` (identical
`48/48` for the real table).

Proofs (no hand-copy anywhere: TSVs generated by script from the
donor literals, round-trip tested order-sensitive 42/48/48):
- Era 1122: inline == lib == cached live map (42 lines, byte-identical).
- Era 1165: inline == lib == cached live map (48 lines, byte-identical).
- Era 1201: inline == lib (48 lines, byte-identical). The provisioned
  cache map was a stale 36-line pre-renderer file (2026-09-11 02:37,
  T4 era — no live 1201 run since the renderer rows landed); the
  refactored wrapper regenerates the 48-line map, diff-empty vs the
  proof. The stale file is inert (derive rewrites it every run).

Wrapper results (generic mechanics → `live_*` calls, derive → lib,
WANT → TSV; local: env/pins, client-pin refetch, javac, cover walk,
Reobf, java-52, R2, deploy, registration greps, era pin helpers):
- 1122: 614 → 363 eSLOC, `BUILD_ONLY=1` offline green (host JDK 8,
  pinned toolchain), regen map == proof.
- 1165: 680 → 416 eSLOC, `BUILD_ONLY=1` offline green (host JDK 8),
  regen map == proof.
- 1201: 905 → 442 eSLOC, `BUILD_ONLY=1` offline green with
  `JAVA17_HOME=jdk21` stand-in (Temurin 17.0.20 absent from this
  machine; flow-proof only — dist bytes are toolchain-sensitive and
  not compared cross-toolchain), regen map == proof.
- Shell over-ceiling count: 3 → 0 (`live-derive.sh` itself at 432 is
  the largest shell file and stays under). Gate semantics unchanged
  (advisory, same as Java `*` flags): hardening the shell alert into
  a failure is a shared-`check.sh` behavior change for all bridges'
  CI and lands as its own decision, never smuggled in here.
- Remaining natural step: full live 1201 boot (steps 5-7) on the
  refactored wrapper — first live run with the 48-line renderer map.

## Addendum — 1201 full live validates the refactored harness (2026-09-11)

First live run with the 48-line renderer map on the thin wrapper
(bridge-1201 `27f3247`) + lib (hub `44a762d`): host machine-local
Temurin 17.0.20, `D3_OFFLINE=1` warm cache, full 150 s window —
derive 48 lines, stub + forge pins green, jars built, server ran to
timeout (exit 124), bind clean / ticks clean, `my_ore` + `my_gem`
registration lines present, `live_compare_names` world == pure union
(1922 cells, `example1:my_ore` + `minecraft:stone`), zero `E_*` /
linkage. Green first try, no code change on either side. This closes
the remaining step named in the previous addendum; its `jdk21`
stand-in caveat dies with it (flow-proof superseded by a
real-toolchain boot — dist bytes stay toolchain-sensitive, still
never compared cross-toolchain).

## Addendum — shell ceiling hardened from advisory to gate failure (2026-09-11)

The re-opener named in the derive-cut addendum lands here, as its own
decision: `tools/check_sloc.py` full scan exits 1 with
`FAIL (sloc-ceiling ...)` on any shell script >= 450 eSLOC (was
`alert ...`, exit 0), and `hub/tools/check.sh` runs the verdict-only
`--check-ceiling` mode after `--self-test` — so hub CI (which checks
out every sibling at `ref: main` and runs the shared check) refuses an
over-ceiling shell anywhere in the org. Java `*` flags stay advisory
prints by design (`AGENTS.md` §3 design alert ; 5 files currently over
— 4 `MatouBridgeMod` at 503-566 plus `MatouParse` at 505 — so failing
on Java would turn every gate red today ; Java hardening is NOT
smuggled in here).

Margins at hardening (green, 0 over): nearest file
`bridge-1201/tools/run-live.sh` at 442 eSLOC (8 under), then
`hub/tools/live-derive.sh` at 432 and
`bridge-1165/tools/run-live.sh` at 416. A wrapper regrowing past the
ceiling gets table-driven treatment, era-split extraction, or deletion
— never split satellites (`AGENTS.md` §3).

## What would re-open it

- Java ceiling hardening: its own decision once the 5 over-ceiling
  sources are refactored under (same shape as this cut — fail loud,
  never smuggled).
- A fifth bridge: scaffold a thin wrapper from day one (pins + derive),
  never a fifth copy of the shared steps (`tools/scaffold-bridge.sh`
  placeholder should point here).
- A shared step that needs per-version branching beyond args: split the
  function by era (precedent: `pin_game/pin_lib` stayed 1201-local until
  a second consumer exists), never `if SFX` inside the common lib.
