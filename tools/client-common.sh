#!/bin/sh
# client-common.sh — shared bridge resolution + per-version table for the
# hub dev-client helpers (run-client.sh, verify-client-save.sh). SOURCED,
# never executed. NOT a gate.
#
# Moved here from bridge-1165 (SSOT): the four bridges differ on five axes
# (Java toolchain, mod metadata, slim-vs-FAT assembly, SRG source, Prism
# maturity), so the table below carries exactly what cannot be derived, and
# everything else derives from the bridge tree or the provisioned live dir:
#   - MODS_STYLE derives from forge/src/META-INF/mods.toml presence
#     (present = mods.toml era, absent = mcmod.info era).
#   - FAT derives from MODS_STYLE: the mods.toml era (1.13+, ModLauncher /
#     securejarhandler) isolates every mods/ jar, so a slim bridge dies
#     with NoClassDefFoundError (found live in D3, then E3); the mcmod.info
#     era (LaunchWrapper, flat classpath) runs the slim 3-jar set the
#     server deploys. Env FAT=0|1 overrides a future bridge that breaks
#     this correlation — loudly documented at the call site, never silent.
#   - ASM_PIN names the exact jar the bridge run-live.sh provisions (that
#     file owns the pin and its sha1; this table only reuses the
#     provisioned bytes — run-client.sh refuses loudly if the live
#     run-live.sh pin drifts from this row).
#   - SRG derives from $LIVE_DIR/srg-narrow.srg, falling back to $SRG_MCP
#     (the 1710 ForgeGradle file); missing both fails loudly.
#
# Contract:
#   BRIDGE  bridge checkout dir (wrappers pass their own dir; direct hub
#           use passes --bridge or $BRIDGE). Unset = auto-detect only when
#           exactly one ../bridge-*/ sibling resolves, else loud failure.
# Exports: BRIDGE SFX MC FORGE_COMP LIVE_TAG LIVE_DIR CLIENT_DIR INST
#          JB JFLAGS JAVA_HOME SRG_DEFAULT ASM_PIN NOTE PACK_FORMAT
# PACK_FORMAT is the resource-pack format the DEV mods/ jars must declare
# in pack.mcmeta (empty = stage none): modern Forge holds the "loading
# mods" warning screen when a jar carries no pack metadata (measured on
# 1201). Only versions with a measured value carry one (1165 proven green
# without, legacy eras predate the requirement) — never widen silently.
# Env (no machine paths hardcoded): BRIDGE, CLIENT_DIR, <TAG>_DIR (B3_DIR,
#   C3_DIR, D3_DIR, E3_DIR), JAVA8_HOME, JAVA17_HOME, FAT.
# Depends on $0 pointing at a script in hub/tools (sourced files share it).
set -eu
HUB_TOOLS="$(dirname "$0")"
if [ -z "${BRIDGE:-}" ]; then
  n=0; found=""
  for b in "$HUB_TOOLS"/../../bridge-*/; do
    [ -d "$b" ] && { n=$((n + 1)); found="$b"; }
  done
  if [ "$n" = "1" ]; then
    BRIDGE="$found"
  else
    echo "FAIL client-common : BRIDGE unset and $n ../bridge-*/ siblings (want exactly 1 to guess)"
    echo "fix: BRIDGE=../bridge-1165 sh hub/tools/run-client.sh   (or use the bridge tools/ wrapper)"
    return 1 2>/dev/null || exit 1
  fi
fi
[ -d "$BRIDGE" ] || { echo "FAIL client-common : BRIDGE=<$BRIDGE> absent"; return 1 2>/dev/null || exit 1; }
BRIDGE="$(cd "$BRIDGE" && pwd)"
SFX="${BRIDGE##*bridge-}"
case "$SFX" in
  # SFX | MC | Forge component | live tag | JDK | SRG default | ASM pin | note
  1710) MC="1.7.10"; FORGE_COMP="10.13.4.1614"; LIVE_TAG="B3"; JAVA_MAJOR="8"
    SRG_DEFAULT="$HOME/.gradle/caches/minecraft/net/minecraftforge/forge/1.7.10-10.13.4.1614-1.7.10/srgs/srg-mcp.srg"
    ASM_PIN="asm-all-5.0.3.jar"
    PACK_FORMAT=""
    NOTE="PROVEN 2026-09-09: launcher-free direct proof green (world == pure union, 1274 cells, stone as numeric ID 1); direct client runtime assembled from pinned bytes (1614 installer has no --installClient); server proof stays the B3 verdict.";;
  1122) MC="1.12.2"; FORGE_COMP="14.23.5.2860"; LIVE_TAG="C3"; JAVA_MAJOR="8"
    SRG_DEFAULT=""
    ASM_PIN="asm-debug-all-5.2.jar"
    PACK_FORMAT=""
    NOTE="PROVEN 2026-09-09: launcher-free direct proof green (world == pure union, 1274 cells, stone as numeric ID 1); server proof stays the C3 verdict.";;
  1201) MC="1.20.1"; FORGE_COMP="47.2.0"; LIVE_TAG="D3"; JAVA_MAJOR="17"
    SRG_DEFAULT=""
    ASM_PIN="asm-9.5.jar"
    PACK_FORMAT="15"
    NOTE="PROVEN 2026-09-09: launcher-free direct proof green (world == pure union, 1274 cells, stone only); Prism path UNTESTED (needs Java 17, pinned below); server proof stays the D3 verdict.";;
  1165) MC="1.16.5"; FORGE_COMP="36.2.42"; LIVE_TAG="E3"; JAVA_MAJOR="8"
    SRG_DEFAULT=""
    ASM_PIN="asm-9.6.jar"
    PACK_FORMAT=""
    NOTE="PROVEN 2026-09-09: Prism singleplayer save replays world == pure union (1274 cells, stone only).";;
  *) echo "FAIL client-common : unknown bridge suffix <$SFX> (want 1710|1122|1201|1165)"
    echo "fix: add a row above (copy the 1165 row, adjust MC/FORGE_COMP/LIVE_TAG/JAVA_MAJOR/ASM_PIN)"; return 1 2>/dev/null || exit 1;;
esac
LIVE_ENV="${LIVE_TAG}_DIR"
eval "LIVE_DIR=\${$LIVE_ENV:-\${TMPDIR:-/tmp}/matou-$(printf '%s' "$LIVE_TAG" | tr 'A-Z' 'a-z')-live}"
CLIENT_DIR="${CLIENT_DIR:-$(printf '%s' "$LIVE_DIR" | sed 's/-live$/-client/')}"
[ "$CLIENT_DIR" != "$LIVE_DIR" ] \
  || { echo "FAIL client-common : CLIENT_DIR == LIVE_DIR ($LIVE_DIR, client build/ would sit inside the live cache)"; return 1 2>/dev/null || exit 1; }
INST="matou-$SFX-dev"
if [ "$JAVA_MAJOR" = "17" ]; then
  JAVA_HOME="${JAVA17_HOME:-/usr/lib/jvm/java-17-openjdk}"
  JFLAGS="--release 8"
else
  JAVA_HOME="${JAVA8_HOME:-/usr/lib/jvm/java-8-openjdk}"
  JFLAGS="-source 8 -target 8"
fi
JB="$JAVA_HOME/bin"
