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
#   PRISM_DIR  Prism data root (default ~/.local/share/PrismLauncher;
#              the instance installs to $PRISM_DIR/instances/matou-<sfx>-dev)
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
set -eu
if [ "${1:-}" = "--bridge" ]; then BRIDGE="${2:-}"; shift 2; fi
[ $# = "0" ] || { echo "FAIL run-client : unknown arg <$1> (want [--bridge <dir>]; env carries the rest)"; exit 1; }
# shellcheck disable=SC1091
. "$(dirname "$0")/client-common.sh"
HUB_ABS="$(cd "$(dirname "$0")" && pwd)"
cd "$BRIDGE"
VERSION="${VERSION:-0.0-dev}"
PRISM_DIR="${PRISM_DIR:-$HOME/.local/share/PrismLauncher}"
PRISM_BIN="${PRISM_BIN:-prismlauncher}"

command -v "$PRISM_BIN" >/dev/null 2>&1 \
  || { echo "FAIL run-client : <$PRISM_BIN> not on PATH (install PrismLauncher 11+)"; exit 1; }
[ -x "$JB/java" ] || { echo "FAIL run-client : no Java $JAVA_MAJOR at <$JAVA_HOME>"; exit 1; }
[ -x "$JB/javac" ] || { echo "FAIL run-client : no javac at <$JAVA_HOME>"; exit 1; }
[ -d ../spi/java/src ] || { echo "FAIL run-client : spi sibling absent"; exit 1; }
[ -d ../example1/java/src ] || { echo "FAIL run-client : example1 sibling absent"; exit 1; }
[ -d ../minimap/java/src ] || { echo "FAIL run-client : minimap sibling absent"; exit 1; }
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

# 1. DEV build (same flags as the bridge run-live.sh steps 3-4; dirty tree
#    allowed). normjar/mkjar mirror run-live.sh (DEV bytes, not release).
BLD="$CLIENT_DIR/build"
rm -rf "$BLD" \
  || { echo "FAIL run-client : cannot clear <$BLD>"; exit 1; }
mkdir -p "$BLD/spi" "$BLD/ex1" "$BLD/mini" "$BLD/forge" "$BLD/jars"
# Controlled tree, no spaces in class paths: word-splitting of $JFLAGS and
# $files below is intended (same practice as run-live.sh).
"$JB/javac" $JFLAGS -nowarn -d "$BLD/spi" $(find ../spi/java/src -name '*.java')
"$JB/javac" $JFLAGS -nowarn -cp "$BLD/spi" -d "$BLD/ex1" $(find ../example1/java/src -name '*.java')
"$JB/javac" $JFLAGS -nowarn -cp "$BLD/spi" -d "$BLD/mini" $(find ../minimap/java/src -name '*.java')
"$JB/javac" $JFLAGS -nowarn -cp "$BLD/spi:$BLD/ex1" -d "$BLD/forge" $(find tools/live/stub forge/src -name '*.java')
EPOCH="$(git log -1 --format=%ct 2>/dev/null || date +%s)"
printf 'Manifest-Version: 1.0\nImplementation-Version: %s\n' "$VERSION" > "$BLD/MANIFEST.MF"
if [ "$MODS_STYLE" = "mods.toml" ]; then
  mkdir -p "$BLD/modstoml/META-INF"
  sed "s/@VERSION@/$VERSION/g" forge/src/META-INF/mods.toml > "$BLD/modstoml/META-INF/mods.toml"
else
  cat > "$BLD/mcmod.info" <<EOF
[{"modid": "matoubridge", "name": "MatouBridge", "description": "SPI bridge for Minecraft $MC (reobfuscated SRG).", "version": "$VERSION", "mcversion": "$MC", "authorList": ["matou-dev"], "url": "https://github.com/matou-dev/bridge-$SFX"}]
EOF
fi
normjar() {
  python3 - "$1" "$EPOCH" <<'EOF'
import sys, zipfile, datetime
path, epoch = sys.argv[1], int(sys.argv[2])
# fromtimestamp(tz=utc): same instant as the gate's utcfromtimestamp, minus
# the host-Python 3.12 DeprecationWarning noise in task output.
dt = datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).timetuple()[:6]
zin = zipfile.ZipFile(path)
items = [(i, zin.read(i.filename)) for i in zin.infolist()]
zin.close()
zout = zipfile.ZipFile(path + ".norm", "w", zipfile.ZIP_DEFLATED)
for info, data in items:
    info.date_time = dt
    info.create_system = 0
    zout.writestr(info, data)
zout.close()
EOF
  mv "$1.norm" "$1"
}
mkjar() {
  out="$1"; stage="$2"
  files=$(cd "$stage" && find . -type f | LC_ALL=C sort)
  (cd "$stage" && "$JB/jar" cfm "$out" "$BLD/MANIFEST.MF" $files)
  normjar "$out"
}
mkjar "$BLD/jars/matou-spi.jar" "$BLD/spi"
mkjar "$BLD/jars/matou-example1.jar" "$BLD/ex1"
mkjar "$BLD/jars/matou-minimap.jar" "$BLD/mini"
rm -rf "$BLD/bridgemod" && mkdir -p "$BLD/bridgemod"
cp -r "$BLD/forge/"* "$BLD/bridgemod/"
# Stubs are compile-only: they must never ship (a fake Block on the
# runtime classpath would shadow vanilla). Refuse loudly if leaked.
# META-INF is re-stamped below (a raw @VERSION@ template must never ship).
rm -rf "$BLD/bridgemod/net" "$BLD/bridgemod/cpw" "$BLD/bridgemod/META-INF"
[ -e "$BLD/bridgemod/net" ] || [ -e "$BLD/bridgemod/cpw" ] \
  && { echo "FAIL run-client : stub leak into mod jar"; exit 1; }
if [ "$FAT" = "1" ]; then
  # ModLauncher/securejarhandler isolates every mods/ jar (found live in
  # D3, then E3): a slim bridge cannot see matou-spi.jar next to it, so
  # the bridge ships FAT — spi + example1 classes embedded, same as the
  # server deploy. The mcmod.info era (flat classpath) stays slim.
  cp -r "$BLD/spi/"* "$BLD/ex1/"* "$BLD/bridgemod/"
fi
if [ "$MODS_STYLE" = "mods.toml" ]; then
  mkdir -p "$BLD/bridgemod/META-INF"
  cp "$BLD/modstoml/META-INF/mods.toml" "$BLD/bridgemod/META-INF/mods.toml"
else
  cp "$BLD/mcmod.info" "$BLD/bridgemod/mcmod.info"
fi
mkjar "$BLD/jars/matoubridge.jar" "$BLD/bridgemod"
"$JB/javac" -nowarn -cp "$REOBF_CP" -d "$BLD" tools/live/Reobf.java
"$JB/java" -cp "$BLD:$REOBF_CP" Reobf "$SRG" "$BLD/jars/matoubridge.jar" "$BLD/jars/matoubridge-reobf.jar"
normjar "$BLD/jars/matoubridge-reobf.jar"
# Keep CellUnion compiled: verify-client-save.sh reuses it, so the
# union logic is never duplicated between server verdict and client verify.
"$JB/javac" -nowarn -cp "$BLD/spi:$BLD/ex1" -d "$BLD" tools/live/CellUnion.java
echo "ok run-client : dev jars built ($SFX, VERSION=$VERSION, DEV bytes, not release)"

# 2. Prism instance (MultiMC format, as proven by local Prism 11 instances:
#    instance.cfg + mmc-pack.json + minecraft/ game dir).
IDIR="$PRISM_DIR/instances/$INST"
mkdir -p "$IDIR/minecraft/mods" "$IDIR/minecraft/config/matoubridge"
cat > "$IDIR/mmc-pack.json" <<EOF
{
    "components": [
        {
            "cachedName": "Minecraft",
            "important": true,
            "uid": "net.minecraft",
            "version": "$MC"
        },
        {
            "cachedName": "Forge",
            "uid": "net.minecraftforge",
            "version": "$FORGE_COMP"
        }
    ],
    "formatVersion": 1
}
EOF
# Minimal instance.cfg: Prism fills component metadata on first launch.
cat > "$IDIR/instance.cfg" <<EOF
[General]
ConfigVersion=1.3
InstanceType=OneSix
JavaPath=$JAVA_HOME/bin/java
ManagedPack=false
MaxMemAlloc=4096
MinMemAlloc=1024
OverrideJavaLocation=true
OverrideMemory=true
iconKey=default
name=$INST
notes=matou-dev bridge-$SFX dev client (hub run-client.sh; DEV bytes, not release)
EOF
rm -f "$IDIR/minecraft/mods/"*.jar
if [ "$FAT" = "1" ]; then
  cp "$BLD/jars/matoubridge-reobf.jar" "$IDIR/minecraft/mods/matoubridge.jar"
else
  cp "$BLD/jars/matou-spi.jar" "$BLD/jars/matou-example1.jar" "$BLD/jars/matoubridge-reobf.jar" "$IDIR/minecraft/mods/"
  mv "$IDIR/minecraft/mods/matoubridge-reobf.jar" "$IDIR/minecraft/mods/matoubridge.jar"
fi
rm -rf "$IDIR/minecraft/matou-content" && cp -r ../example1/content "$IDIR/minecraft/matou-content"
GDIR="$IDIR/minecraft"
# packs.cfg: written once, then KEPT. Re-staging must never clobber a dev's
# alias bindings (e.g. hut_wall=oak_planks for a varied hut) back to the
# stone proof defaults — that made "whatever happens it's stone".
if [ -f "$IDIR/minecraft/config/matoubridge/packs.cfg" ]; then
  echo "note run-client : keeping existing packs.cfg (delete it to reset to stone proof defaults):"
  grep -v "^#" "$IDIR/minecraft/config/matoubridge/packs.cfg" || true
else
  printf 'fr.iamacat.example1.ExamplePack 63 minecraft:stone ownedFile=%s/matou-content/owned.matou scatterFile=%s/matou-content/additive.matou structureFile=%s/matou-content/structure.matou block.example1.structures:hut_wall=minecraft:stone block.example1.structures:hut_roof=minecraft:stone\n' "$GDIR" "$GDIR" "$GDIR" > "$IDIR/minecraft/config/matoubridge/packs.cfg"
fi
if [ -n "${TELLME_JAR:-}" ]; then
  [ -f "$TELLME_JAR" ] || { echo "FAIL run-client : TELLME_JAR=<$TELLME_JAR> absent"; exit 1; }
  if [ -n "${TELLME_SHA1:-}" ]; then
    echo "$TELLME_SHA1  $TELLME_JAR" | sha1sum -c - >/dev/null 2>&1 \
      || { echo "FAIL run-client : TellMe sha1 drift (want $TELLME_SHA1)"; exit 1; }
  fi
  cp "$TELLME_JAR" "$IDIR/minecraft/mods/"
  echo "ok run-client : TellMe installed ($(basename "$TELLME_JAR"))"
else
  echo "note run-client : no TELLME_JAR (bridge only). Runtime inspector suggestion:"
  echo "  TellMe for MC $MC (CurseForge) gives /tellme looking-at|holding|batch-run"
  echo "  for NBT/registry dumps; pin its sha1 in TELLME_SHA1 on first download."
fi
if [ -n "${EXTRA_MODS_DIR:-}" ]; then
  [ -d "$EXTRA_MODS_DIR" ] || { echo "FAIL run-client : EXTRA_MODS_DIR=<$EXTRA_MODS_DIR> absent"; exit 1; }
  if [ -f "$EXTRA_MODS_DIR/SHA256SUMS" ]; then
    (cd "$EXTRA_MODS_DIR" && sha256sum -c SHA256SUMS) \
      || { echo "FAIL run-client : extra mods SHA256SUMS mismatch"; exit 1; }
    echo "ok run-client : extra mods pinned (SHA256SUMS verified)"
  else
    echo "note run-client : no SHA256SUMS in <$EXTRA_MODS_DIR> (unverified copy;"
    echo "  create one with (cd dir && sha256sum *.jar > SHA256SUMS) to pin the bytes)"
  fi
  count=$(ls "$EXTRA_MODS_DIR"/*.jar 2>/dev/null | wc -l)
  [ "$count" -gt 0 ] || { echo "FAIL run-client : no jars in <$EXTRA_MODS_DIR>"; exit 1; }
  cp "$EXTRA_MODS_DIR"/*.jar "$IDIR/minecraft/mods/"
  echo "ok run-client : extra mods installed ($count jars)"
  echo "  dev-only, never in dist/: render/RAM/DFU inspectors for MC $MC."
  echo "  If verify-client-save.sh drifts after adding one, the mod"
  echo "  changed placed blocks: drop it loudly, keep the verdict."
fi
echo "ok run-client : instance staged <$IDIR>"
echo "note run-client : $NOTE"

# 3. Play protocol (owned slice, same geometry as the server proof).
cat <<EOF
--- play protocol ($INST, MC $MC / Forge $FORGE_COMP) ---
1. Launch:  prismlauncher --launch "$INST"   (offline works: --offline MatouDev)
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
if [ "${LAUNCH:-}" = "1" ]; then
  exec "$PRISM_BIN" --launch "$INST"
else
  echo "staged (no launch: LAUNCH=1 to exec $PRISM_BIN --launch $INST)"
fi
