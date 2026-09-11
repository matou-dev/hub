#!/bin/sh
# Dev client helper (NOT a gate): stages a Prism Launcher instance
# (matou-<sfx>-dev, MC/Forge per bridge) with a DEV build of the bridge
# plus content, so the proof can be played and inspected in a real game
# instead of only on the nogui server verdict.
#
# SSOT (moved here from bridge-1165): per-bridge thin wrappers exec this
# file with BRIDGE set; direct use passes BRIDGE or --bridge. Per-version
# parameters live in tools/client-common.sh (sourced); everything else
# derives from the bridge tree or the provisioned live dir, never
# re-derived and never defaulted silently.
#
# Reuse contract (no duplication of provisioning truth):
#   - Upstream pins + SRG map come from a provisioned live dir
#     (run the bridge tools/run-live.sh once; needs network). This script
#     never re-derives them: srg-narrow.srg absent and no usable SRG_MCP
#     fails loudly. ASM jars are discovered under server/libraries.
#   - Build flags mirror the bridge run-live.sh steps 3-4 (javac level,
#     metadata style, slim-vs-FAT assembly, Reobf). Bytes are DEV bytes
#     (dirty tree allowed): the release path stays run-live.sh BUILD_ONLY.
#   - World verdict reuses tools/live/anvil.py + CellUnion via
#     hub tools/verify-client-save.sh after you quit the game.
#
# Env (no machine paths hardcoded):
#   BRIDGE / --bridge <dir>  bridge checkout (wrappers set it; unset =
#              auto-detect only when exactly one ../bridge-*/ resolves)
#   CLIENT_DIR work dir (default: live dir with -live -> -client)
#   <TAG>_DIR  provisioned live dir, e.g. E3_DIR (default
#              ${TMPDIR:-/tmp}/matou-<tag>-live)
#   PRISM_DIR  Prism data root (default per-tag isolated root
#              ${TMPDIR:-/tmp}/matou-<tag>-prism, same convention as the
#              live/client dirs in client-common.sh; the live Prism home
#              is refused loudly even when passed explicitly;
#              the instance installs to $PRISM_DIR/instances/matou-<sfx>-dev)
#   MATOU_MODS space-separated matou-dev sibling mods to DEV-build + stage
#              (default "example1"; each needs ../<name>/java/src — absent
#              dir fails loudly). Staging is metadata-aware: the mcmod.info
#              era (flat classpath) copies every listed mod jar next to the
#              bridge, while the mods.toml era (isolated jars) only stages
#              a mod jar carrying Forge metadata (mods.toml or mcmod.info)
#              and refuses a metadata-less one loudly — an unmarked jar
#              would break the ModLauncher boot silently-ish. example1
#              stays embedded in the FAT bridge (server parity) and is
#              required there; minimap has no Forge wrapper yet, so it
#              stages on slim eras and fails loud on FAT ones until that
#              tranche lands (never skipped silently).
#   PRISM_BIN  launcher binary (default prismlauncher on PATH)
#   JAVA8_HOME / JAVA17_HOME per-bridge toolchain (defaults /usr/lib/jvm/...)
#   FAT=0|1    override the derived slim-vs-FAT assembly (default derives
#              from mods.toml presence, see client-common.sh)
#   VERSION    stamp (default 0.0-dev; DEV bytes, never a release)
#   TELLME_JAR optional runtime inspector mod jar copied into mods/;
#              TELLME_SHA1 optionally pins it. Unset = bridge only, plus a
#              printed suggestion. The script never downloads unknown bytes.
#   EXTRA_MODS_DIR optional dir of extra dev-comfort mod jars copied into
#              mods/; an optional SHA256SUMS file inside is verified first.
#              Perf mods stay dev-only: they never ship in dist/ and must
#              never change placed blocks (render/RAM/DFU only) — a verdict
#              drift after adding one fails loudly in the verifier, which
#              is the point. The script never downloads mods itself.
#   LAUNCH=1   actually exec prismlauncher --launch (default prints the
#              command; launching needs a display and blocks the shell).
#              The game always launches OFFLINE as $OFFLINE_NAME
#              (default MatouDev): deterministic player UUID, no account
#              needed — without it Prism waits on an account dialog.
#   AUTOPLAY=1 build + stage the dev-only autoplay companion
#              (bridge tools/autoplay/, needs want.txt + client-pin.txt)
#              and preseed a fresh flat world. NOT a gate.
#   XVFB=1     launch under xvfb-run (implies LAUNCH=1, headless play;
#              Qt pinned to xcb + WAYLAND_DISPLAY dropped, so the window
#              can never leak onto a real Wayland session).
#   AUTOVERIFY=1 after the game exits, replay verify-client-save.sh on
#              $AUTOPLAY_WORLD (default matou) and exit with its status.
#              AUTOPLAY_WORLD names the proof world (preseed + companion
#              + verify read the same value).
set -eu
if [ "${1:-}" = "--bridge" ]; then BRIDGE="${2:-}"; shift 2; fi
[ $# = "0" ] || { echo "FAIL run-client : unknown arg <$1> (want [--bridge <dir>]; env carries the rest)"; exit 1; }
# shellcheck disable=SC1091
. "$(dirname "$0")/client-common.sh"
# shellcheck disable=SC1091
. "$(dirname "$0")/live-common.sh"
live_init "run-client"
HUB_ABS="$(cd "$(dirname "$0")" && pwd)"
cd "$BRIDGE"
VERSION="${VERSION:-0.0-dev}"
PRISM_BIN="${PRISM_BIN:-prismlauncher}"
# Never touch the user's live Prism home: automated runs stage into
# isolated roots only (a launch without -d once rewrote accounts.json).
# PRISM_DIR already defaults to a per-tag isolated root (client-common.sh);
# only an explicit live home lands here — refused loudly.
case "${PRISM_DIR%/}" in
  "$HOME/.local/share/PrismLauncher")
    echo "FAIL run-client : PRISM_DIR is the live user dir ($HOME/.local/share/PrismLauncher)"
    echo "fix: unset PRISM_DIR (per-tag isolated default) or point it at another isolated root"; exit 1;;
esac

command -v "$PRISM_BIN" >/dev/null 2>&1 \
  || { echo "FAIL run-client : <$PRISM_BIN> not on PATH (install PrismLauncher 11+)"; exit 1; }
[ -x "$JB/java" ] || { echo "FAIL run-client : no Java $JAVA_MAJOR at <$JAVA_HOME>"; exit 1; }
[ -x "$JB/javac" ] || { echo "FAIL run-client : no javac at <$JAVA_HOME>"; exit 1; }
[ -d ../spi/java/src ] || { echo "FAIL run-client : spi sibling absent"; exit 1; }
# Dynamic matou-dev mod set (default: the proven content backend only).
# Names, never paths: each must resolve to a sibling source tree.
MATOU_MODS="${MATOU_MODS:-example1}"
for m in $MATOU_MODS; do
  case "$m" in ""|*/*|*.*) echo "FAIL run-client : MATOU_MODS bad entry <$m> (want plain sibling names, e.g. MATOU_MODS=\"example1 minimap\")"; exit 1;; esac
  [ -d "../$m/java/src" ] \
    || { echo "FAIL run-client : <$m> sibling absent (../$m/java/src; clone it next to hub or drop <$m> from MATOU_MODS)"; exit 1; }
done
command -v python3 >/dev/null || { echo "FAIL run-client : python3 required (Reobf/normjar)"; exit 1; }
# Provisioning truth comes from the live pipeline, never re-derived here.
SRG_NARROW="$LIVE_DIR/srg-narrow.srg"
if [ -f "$SRG_NARROW" ]; then
  SRG="$SRG_NARROW"
elif [ -n "${SRG_MCP:-$SRG_DEFAULT}" ] && [ -f "${SRG_MCP:-$SRG_DEFAULT}" ]; then
  SRG="${SRG_MCP:-$SRG_DEFAULT}"
else
  echo "FAIL run-client : no SRG map ($SRG_NARROW absent, SRG_MCP unusable)"
  echo "fix: run tools/run-live.sh once first (provisions + pins upstream), or point $LIVE_ENV at a provisioned dir"
  exit 1
fi
ASM=$(find "$LIVE_DIR/server/libraries/org/ow2/asm" -name "$ASM_PIN" 2>/dev/null | head -n 1 || true)
[ -n "$ASM" ] \
  || { echo "FAIL run-client : ASM $ASM_PIN absent under <$LIVE_DIR/server/libraries/org/ow2/asm> (run tools/run-live.sh once first)"; exit 1; }
PIN_LIVE="$(grep '^ASM_PIN=' tools/run-live.sh | head -n 1 | cut -d'"' -f2 || true)"
[ "$PIN_LIVE" = "$ASM_PIN" ] \
  || { echo "FAIL run-client : ASM pin drift (table $ASM_PIN vs run-live.sh ${PIN_LIVE:-absent} — bump the client-common.sh row, never silently)"; exit 1; }
case "$ASM_PIN" in *all*.jar) REOBF_CP="$ASM";;
  *) AV="$(printf '%s' "$ASM_PIN" | sed 's/^asm-//; s/\.jar$//')"
    ASM_COMMONS=$(find "$LIVE_DIR/server/libraries/org/ow2/asm/asm-commons/$AV" -name "asm-commons-$AV.jar" 2>/dev/null | head -n 1 || true)
    [ -n "$ASM_COMMONS" ] \
      || { echo "FAIL run-client : asm-commons-$AV.jar absent next to $ASM_PIN (run tools/run-live.sh once first)"; exit 1; }
    REOBF_CP="$ASM:$ASM_COMMONS";;
esac
if [ -f forge/src/META-INF/mods.toml ]; then MODS_STYLE="mods.toml"; else MODS_STYLE="mcmod.info"; fi
if [ -n "${FAT:-}" ]; then
  case "$FAT" in 0|1) ;; *) echo "FAIL run-client : FAT=<$FAT> (want 0|1)"; exit 1;; esac
elif [ "$MODS_STYLE" = "mods.toml" ]; then FAT=1; else FAT=0; fi

# Era-bound adapters: live-common.sh owns the mechanics (hub
# decisions/LIVE_SHELL_COMMON.md); these bind the caller-owned dirs/tools
# so every call site below stays byte-identical.
mkjar() { live_mkjar "$1" "$2" "$BLD/MANIFEST.MF" "$JB/jar" "$EPOCH"; }
normjar() { live_normjar "$1" "$EPOCH"; }
stage_packmcmeta() { live_stage_packmcmeta "$1" "$2"; }
mod_has_metadata() { live_mod_has_metadata "$JB/jar" "$1"; }
# 1. DEV build (same flags as the bridge run-live.sh steps 3-4; dirty tree
#    allowed). normjar/mkjar mirror run-live.sh (DEV bytes, not release).
BLD="$CLIENT_DIR/build"
rm -rf "$BLD" \
  || { echo "FAIL run-client : cannot clear <$BLD>"; exit 1; }
mkdir -p "$BLD/spi" "$BLD/forge" "$BLD/jars"
EPOCH="$(git log -1 --format=%ct 2>/dev/null || date +%s)"
printf 'Manifest-Version: 1.0\nImplementation-Version: %s\n' "$VERSION" > "$BLD/MANIFEST.MF"
# Controlled tree, no spaces in class paths: word-splitting of $JFLAGS and
# $files below is intended (same practice as run-live.sh).
"$JB/javac" $JFLAGS -nowarn -d "$BLD/spi" $(find ../spi/java/src -name '*.java')
MOD_CP="$BLD/spi"
for m in $MATOU_MODS; do
  mkdir -p "$BLD/mod-$m" "$BLD/modstage-$m"
  "$JB/javac" $JFLAGS -nowarn -cp "$BLD/spi" -d "$BLD/mod-$m" $(find "../$m/java/src" -name '*.java')
  cp -r "$BLD/mod-$m/"* "$BLD/modstage-$m/"
  # Same pack.mcmeta discipline as the bridge jar below: a staged mod jar
  # with Forge metadata on a PACK_FORMAT era must declare it, or modern
  # Forge holds the "loading mods" warning screen (measured on 1201).
  # Slim eras (PACK_FORMAT empty) stage bare jars, exactly as before.
  stage_packmcmeta "$BLD/modstage-$m" "Matou $m DEV (hub run-client.sh, not release)"
  mkjar "$BLD/jars/matou-$m.jar" "$BLD/modstage-$m"
  MOD_CP="$MOD_CP:$BLD/mod-$m"
done
# Spike stage (1710 repop, absent elsewhere): bridge-owned zero-MC sources
# the forge hook links against. ${SPIKE:+...} vanishes when the dir is
# absent, so other bridges compile exactly as before.
SPIKE=""
[ -d java/src ] && SPIKE="java/src"
"$JB/javac" $JFLAGS -nowarn -cp "$MOD_CP" -d "$BLD/forge" $(find ${SPIKE:+$SPIKE} tools/live/stub forge/src -name '*.java')
if [ "$MODS_STYLE" = "mods.toml" ]; then
  mkdir -p "$BLD/modstoml/META-INF"
  sed "s/@VERSION@/$VERSION/g" forge/src/META-INF/mods.toml > "$BLD/modstoml/META-INF/mods.toml"
else
  cat > "$BLD/mcmod.info" <<EOF
[{"modid": "matoubridge", "name": "MatouBridge", "description": "SPI bridge for Minecraft $MC (reobfuscated SRG).", "version": "$VERSION", "mcversion": "$MC", "authorList": ["matou-dev"], "url": "https://github.com/matou-dev/bridge-$SFX"}]
EOF
fi
mkjar "$BLD/jars/matou-spi.jar" "$BLD/spi"
rm -rf "$BLD/bridgemod" && mkdir -p "$BLD/bridgemod"
cp -r "$BLD/forge/"* "$BLD/bridgemod/"
# Stubs are compile-only: they must never ship (a fake Block on the
# runtime classpath would shadow vanilla). Refuse loudly if leaked.
# META-INF is re-stamped below (a raw @VERSION@ template must never ship).
# com/ rides along since the 1165 renderer tranche (Mojang-class stubs
# beside the net/* + org/* ones — a fake MatrixStack on the runtime
# classpath would shadow the real class).
rm -rf "$BLD/bridgemod/net" "$BLD/bridgemod/cpw" "$BLD/bridgemod/org" "$BLD/bridgemod/com" "$BLD/bridgemod/META-INF"
[ -e "$BLD/bridgemod/net" ] || [ -e "$BLD/bridgemod/cpw" ] || [ -e "$BLD/bridgemod/org" ] || [ -e "$BLD/bridgemod/com" ] \
  && { echo "FAIL run-client : stub leak into mod jar"; exit 1; }
if [ "$FAT" = "1" ]; then
  # ModLauncher/securejarhandler isolates every mods/ jar (found live in
  # D3, then E3): a slim bridge cannot see matou-spi.jar next to it, so
  # the bridge ships FAT — spi + example1 classes embedded, same as the
  # server deploy. The mcmod.info era (flat classpath) stays slim.
  # example1 stays required here: the default packs.cfg below wires its
  # ExamplePack, and the FAT bridge is its only classpath home.
  case " $MATOU_MODS " in
    *" example1 "*) ;;
    *) echo "FAIL run-client : MATOU_MODS=<${MATOU_MODS:-}> lacks example1 (FAT era embeds it — server parity, default packs.cfg wires it)"; exit 1;;
  esac
  cp -r "$BLD/spi/"* "$BLD/mod-example1/"* "$BLD/bridgemod/"
fi
if [ "$MODS_STYLE" = "mods.toml" ]; then
  mkdir -p "$BLD/bridgemod/META-INF"
  cp "$BLD/modstoml/META-INF/mods.toml" "$BLD/bridgemod/META-INF/mods.toml"
else
  cp "$BLD/mcmod.info" "$BLD/bridgemod/mcmod.info"
fi
stage_packmcmeta "$BLD/bridgemod" "MatouBridge DEV (hub run-client.sh, not release)"
mkjar "$BLD/jars/matoubridge.jar" "$BLD/bridgemod"
"$JB/javac" -nowarn -cp "$REOBF_CP" -d "$BLD" tools/live/Reobf.java
"$JB/java" -cp "$BLD:$REOBF_CP" Reobf "$SRG" "$BLD/jars/matoubridge.jar" "$BLD/jars/matoubridge-reobf.jar"
normjar "$BLD/jars/matoubridge-reobf.jar"
# Keep CellUnion compiled: verify-client-save.sh reuses it, so the
# union logic is never duplicated between server verdict and client verify.
"$JB/javac" -nowarn -cp "$MOD_CP" -d "$BLD" tools/live/CellUnion.java
echo "ok run-client : dev jars built ($SFX, VERSION=$VERSION, DEV bytes, not release)"

. "$HUB_ABS/client-autoplay.sh"
. "$HUB_ABS/client-prism.sh"

# 3. Play protocol (owned slice, same geometry as the server proof).
cat <<EOF
--- play protocol ($INST, MC $MC / Forge $FORGE_COMP) ---
1. Launch:  prismlauncher -d "$PRISM_DIR" --launch "$INST" -o "$OFFLINE_NAME"   (offline name, deterministic UUID)
   First launch downloads MC $MC + Forge $FORGE_COMP into the instance (network once).
2. Singleplayer: create NEW world named "matou", game mode Creative, FLAT type.
   The wire lands plane cells at y=63 and hut volumes at y=64..65 around the
   origin (chunks 0..1, rows -1..1) — same 1274-cell stone union as $LIVE_TAG.
   STAY near spawn ~4 min (4000 ticks) without wandering: every tick decides
   DIFFERENT cells (tick-addressed RNG), so a chunk unloaded mid-run loses
   its early cells forever — the union only accumulates in continuously
   loaded chunks. Wandering first, verifying later always undercounts.
3. Owned check (backend seul): fresh flat world shows the stone hut near
   spawn; nothing else changes. Compat check (additif tardif): open any
   existing vanilla world instead — vanilla builds stay intact, our cells
   only append where absent (never replace, never duplicate).
4. Runtime values: F3 screen for pos/chunk; /tellme looking-at for block NBT
   (if TellMe installed); instance log for E_FORGE/E_BRIDGE/E_EXAMPLE refusals
   (loud, never silent); MinimapJob rows stay server-side proof (M3) until a
   client blit lands them.
5. Quit the game (flush the save), then:
     sh $HUB_ABS/verify-client-save.sh --bridge $BRIDGE [world-name]   (default: matou)
   replays the $LIVE_TAG verdict (world == pure union) on the client save.
EOF
if [ "${XVFB:-}" = "1" ]; then
  command -v xvfb-run >/dev/null \
    || { echo "FAIL run-client : xvfb-run absent (XVFB=1 needs it)"; exit 1; }
  LAUNCH=1
  # Headless means HEADLESS: Qt prefers Wayland when WAYLAND_DISPLAY leaks
  # into this env, so a virgin Prism pops onto the real screen (looking
  # exactly like wiped accounts). Pin Qt to the Xvfb display instead.
  QT_QPA_PLATFORM=xcb; export QT_QPA_PLATFORM
  unset WAYLAND_DISPLAY
  # No audio device under Xvfb either: null OpenAL driver (same pin as
  # run-client-direct.sh; manual LAUNCH without XVFB keeps real sound).
  ALSOFT_DRIVERS="${ALSOFT_DRIVERS:-null}"; export ALSOFT_DRIVERS
  echo "note run-client : XVFB=1 implies LAUNCH=1 (headless play under Xvfb)"
fi
if [ "${LAUNCH:-}" = "1" ]; then
  if [ "${AUTOVERIFY:-}" = "1" ]; then
    # Automated proof: play (or fail loud), then judge the save. The game
    # exit code is reported but the verdict owns the script exit status.
    if [ "${XVFB:-}" = "1" ]; then
      xvfb-run -a "$PRISM_BIN" -d "$PRISM_DIR" --launch "$INST" -o "$OFFLINE_NAME"
    else
      "$PRISM_BIN" -d "$PRISM_DIR" --launch "$INST" -o "$OFFLINE_NAME"
    fi
    rc=$?
    echo "note run-client : game exited ($rc), replaying verdict on <$WORLD>"
    sh "$HUB_ABS/verify-client-save.sh" --bridge "$BRIDGE" "$WORLD"
    exit $?
  fi
  if [ "${XVFB:-}" = "1" ]; then
    exec xvfb-run -a "$PRISM_BIN" -d "$PRISM_DIR" --launch "$INST" -o "$OFFLINE_NAME"
  fi
  exec "$PRISM_BIN" -d "$PRISM_DIR" --launch "$INST" -o "$OFFLINE_NAME"
else
  echo "staged (no launch: LAUNCH=1 to exec $PRISM_BIN -d $PRISM_DIR --launch $INST -o $OFFLINE_NAME)"
fi
