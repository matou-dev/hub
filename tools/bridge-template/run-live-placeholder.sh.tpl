#!/bin/sh
# @P3@ live gate (TODO, scaffolded): Forge @MC@ (@FORGE_LONG@) server run
# proving PackWire.bind (real Block resolve) plus world-tick apply on a real
# world, then comparing the world against the pure decision union.
#
# Scaffold placeholder: the live run is NOT wired yet. Port tools/run-live.sh
# from bridge-@REF_SFX@ (same phases, new pins) before claiming @P3@ :
#   1. FORGE_URL (default below) + reproducibility pins (installer /
#      universal / mappings / ASM sha1) measured from one provisioned run.
@MAPPING_GUIDE@#   3. Dockerfile cache notes + live-proof.yml dispatch.
# Refuse-loud contract: with LIVE=1 this placeholder fails (never a silent
# green); without LIVE=1 tools/check.sh skips it (never blocking).
#
# Env (no machine paths hardcoded):
#   @LIVE_DIR@   work dir (default ${TMPDIR:-/tmp}/matou-@LIVE_TAG_LOWER@-live)
#   JAVA8_HOME Java 8 home (default /usr/lib/jvm/java-8-openjdk)
#   FORGE_URL  installer URL (default Maven @FORGE_LONG@ installer)
#   BOOT_SECS  server run time (default 150; short runs fail coverage loudly)
set -eu
cd "$(dirname "$0")/.."
@LIVE_DIR@="${@LIVE_DIR@:-${TMPDIR:-/tmp}/matou-@LIVE_TAG_LOWER@-live}"
JAVA8_HOME="${JAVA8_HOME:-/usr/lib/jvm/java-8-openjdk}"
FORGE_URL="${FORGE_URL:-@FORGE_URL@}"
BOOT_SECS="${BOOT_SECS:-150}"
echo "FAIL @FAIL_TAG@ : live not wired yet (phase @P3@ todo) — port tools/run-live.sh from bridge-@REF_SFX@, fill FORGE_URL/pins, then re-run with LIVE=1"
exit 1
