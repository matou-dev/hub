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

`hub/tools/run-client-direct.sh` (DEV ONLY, NOT a gate) plays
the staged instance with no launcher: the official Forge installer
provisions the client runtime once (cached), then plain java replays
the production ModLauncher invocation headless under `xvfb-run`. No
Prism process ever runs here — no accounts, no Qt, no Wayland leak by
construction. Flow is two commands, zero duplicated staging:
`AUTOPLAY=1 … run-client.sh` stages DEV jars + content + packs.cfg and
preseeds a fresh world, then
`run-client-direct.sh` provisions, plays, and replays the verdict.

1165+1122+1201 guard (`run-client-direct.sh` case table): any other `SFX` fails
loud with "no measured client pins (provision once, pin, extend the
table below)". Measured pins, never silent upgrades: vanilla json URL +
SHA1 per version (`run-client-direct.sh` case table: 1.16.5 fba9f783…,
1.12.2 832d95b9…, 1.20.1 f54b1a9b…), installer `INSTALLER_SHA1` reused from the bridge
`run-live.sh` (per-version value), assets sha1-addressed missing-only
(same code across eras), libraries fetched from pinned json
entries with sha1 check, Forge-first classpath dedup on group:artifact
conflicts, unknown `${placeholder}` = loud. CWD is the game dir: the
bridge reads `config/matoubridge/packs.cfg` RELATIVE, Q1-passive.
`WAYLAND_DISPLAY` is unset before play; `VERIFY=0` skips the verdict,
default replays `verify-client-save.sh` and the verdict owns the exit
status.

Per-era launch assembly (measured per version, never assumed): modern
era (arguments dict, e.g. 1165) assembles jvm+game from the json dicts;
legacy era (<=1.12, no arguments dict, LaunchWrapper main, e.g. 1122)
synthesizes `-Djava.library.path` + explicit `-cp` (the era launcher
built -cp itself — the json carries none) and splits the Forge
`minecraftArguments` string. First 1122 run died with "cannot find
LaunchWrapper" until -cp went explicit. The 1201 row adds its own
measured shape: join via the official `--quickPlaySingleplayer` launch
argument (no programmatic join surface on modern versions), the
installer-provided client-extra replaces the vanilla primary (both
carry `net.minecraft.obfuscate` and JPMS dies with a split-package
ResolutionException otherwise — same trust chain as the D3 server-extra),
modern separate natives libs ride the classpath (never the flattened
extractor), and Forge jvm args assemble Forge-first (1.20 needs its
`--add-opens`; 1165 ran green without its 4 Forge jvm args only because
ModLauncher never required them — latent).

Stop clock is SERVER ticks from 1122 on (1165 stays as proven): the
bridge applies on the server thread, and on one JVM the client can
out-tick a loaded server — stopping on client ticks under-counted the
addressed union (measured 967/1274 on the first 1122 run). The server
handler only counts (`volatile`, the client handler owns the shutdown
call — same thread as the proven 1165 quit path). WAIT overshoots 4000
on purpose in both clocks (slow start re-lands the same deterministic
cells — the union is a fixed point).

Headless pin: `run-client.sh` forces `pauseOnLostFocus:false` into the
staged game dir (create or amend, never clobbers a dev's file):
singleplayer auto-pauses on lost focus and under Xvfb the window never
owns the focus — measured on 1122 as 1 world tick played then silence
until timeout.

Numeric verdict (pre-flattening eras): 1.7.10/1.12.2 region files store
numeric block IDs (`verify-client-save.sh` `NUMERIC_FROZEN` table,
stone = 1, same fact the C3 server verdict compares against), 1.13+
palettes print namespaced names. Same contract, other representation;
a name without a frozen row fails loudly.

Found through this path (measured, not assumed): autoplay derive
SRG-slot fix (Reobf maps MCP->LEFT, the `LEFT slot is SRG` blocks in
`run-client.sh` — MCP era and Mojmap era each derive narrow SRG the
same shape as the live srg-narrow.srg),
WorldGenSettings preseed (bridge-1165 `4c08403`, legacy generator
tags ignored on 1.16.5), Qt-xcb pin under XVFB, game-dir CWD.

Headless hardening: the game runs under an internal `GAME_TIMEOUT`
watchdog (default 600s — past the deadline the run FAILs with a log
tail, never hangs to the outer timeout), audio is forced to the null
OpenAL driver (`ALSOFT_DRIVERS=null` — no audio device under Xvfb, in
both direct and Prism-XVFB paths), and DEV mods/ jars stage pack.mcmeta
(`PACK_FORMAT` per-version row in `client-common.sh`, 1201 → 15 —
Reobf passes non-class entries through, normjar keeps bytes
deterministic). The 1201 need was measured, not assumed: both DEV jars
lacked pack.mcmeta, modern Forge held the "loading mods" warning screen
(`Missing metadata in pack mod:matoubridge/matouautoplay`), quick-play
never fired, the run died by timeout (found via screenshot + jstack —
Render thread idle in glfwWaitEventsTimeout).

## Gates

- Green runs (1165, 1122, 1201): world == pure union (1274 cells,
  stone only — same count as every live proof; numeric ID 1 on
  pre-flattening eras, namespaced names on 1.13+).
- 1201 went green on re-proof once pack.mcmeta was staged (quick-play
  join ~16s after boot, clean exit 0 after ~4 min, 600s watchdog never
  fired) — the red cause above is closed.
- `tools/check.sh` green; other versions stay refused until provisioned
  and pinned per version.

## What would re-open it

- The remaining 1710 row: provision once, pin its vanilla json +
  installer + ASM row, port the companion WANT + preseed shape, extend
  the `case SFX` table and the era assembly if the json shape is new —
  never widen the guard silently.
- Prism stays the manual-dev convenience; automation never grows a
  launcher dependency back.
