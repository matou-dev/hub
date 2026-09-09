#!/bin/sh
# dev-loop.sh — fast mod-dev loop (NOT a gate): pure seconds by default,
# live only on explicit flags, never live on a red tree.
#
# The "1h per feature" syndrome came from reaching for the 150s server
# proof (plus provision + client ~4-10min) on every edit. The loop is
# layered instead — each etage delegates to the owning script, this file
# only orders them fail-fast and never re-derives their truth:
#   E0 pure (default, seconds): hub check.sh (parity) + bridge check.sh
#      with LIVE explicitly cleared (pure even if the caller exported
#      LIVE=1 — live needs --server/--client, said loudly below).
#   E1 --server (minutes): E0 green first, then LIVE=1 bridge check
#      (server proof; BOOT_SECS/B3_OFFLINE/JAVA8_HOME/... pass through
#      untouched; short BOOT_SECS fails coverage loudly by bridge
#      design — tools/run-live.sh owns that rule).
#   E2 --client (minutes): E0 green first, then the documented two-command
#      direct flow (run-client-direct.sh header): AUTOPLAY=1 staging +
#      launcher-free play + verdict (PRISM_DIR/AUTOPLAY_WORLD/VERIFY/
#      GAME_TIMEOUT pass through; defaults agree by construction).
#      Needs one prior server provision (the installer bytes live in the
#      live dir) — an absent provision fails loudly in the callee with
#      the fix, never here.
#
# Env (no machine paths hardcoded):
#   BRIDGE / --bridge <dir>  bridge checkout (unset = auto-detect only
#              when exactly one ../../bridge-*/ sibling resolves, same
#              convention as run-client.sh; ambiguous = loud).
#   --server   run E1 after E0.
#   --client   run E2 after E0 (combinable with --server).
#   --offline  export B3_OFFLINE=1 (reuse provision cache, never download;
#              missing cache fails loudly in the callee).
set -eu
HUB_TOOLS="$(cd "$(dirname "$0")" && pwd)"
BRIDGE="${BRIDGE:-}"
WANT_SERVER=0
WANT_CLIENT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --bridge) BRIDGE="${2:-}"; shift 2;;
    --server) WANT_SERVER=1; shift;;
    --client) WANT_CLIENT=1; shift;;
    --offline) B3_OFFLINE=1; export B3_OFFLINE; shift;;
    *) echo "FAIL dev-loop : unknown arg <$1> (want [--bridge <dir>] [--server] [--client] [--offline])"; exit 1;;
  esac
done
if [ -z "$BRIDGE" ]; then
  n=0; pick=""
  for b in "$HUB_TOOLS"/../../bridge-*/; do
    [ -d "$b" ] || continue
    n=$((n + 1)); pick="$b"
  done
  [ "$n" = "1" ] || { echo "FAIL dev-loop : BRIDGE ambiguous ($n ../../bridge-*/ siblings; pass --bridge <dir>)"; exit 1; }
  BRIDGE="$pick"
fi
[ -d "$BRIDGE/tools" ] || { echo "FAIL dev-loop : bridge <$BRIDGE> has no tools/ (pass --bridge <dir>)"; exit 1; }
echo "note dev-loop : E0 pure (LIVE cleared for this etage; live needs --server/--client)"
sh "$HUB_TOOLS/check.sh"
LIVE= sh "$BRIDGE/tools/check.sh"
echo "ok dev-loop : E0 pure green"
if [ "$WANT_SERVER" = "1" ]; then
  LIVE=1 sh "$BRIDGE/tools/check.sh"
fi
if [ "$WANT_CLIENT" = "1" ]; then
  AUTOPLAY=1 sh "$HUB_TOOLS/run-client.sh" --bridge "$BRIDGE"
  sh "$HUB_TOOLS/run-client-direct.sh" --bridge "$BRIDGE"
fi
echo "ok dev-loop : done (server=$WANT_SERVER client=$WANT_CLIENT)"
