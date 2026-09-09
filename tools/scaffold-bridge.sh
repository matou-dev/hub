#!/bin/sh
# Scaffold a new matou-dev/bridge-<sfx> (C1+C2 green, live TODO).
#
# Copies version-independent files from a reference bridge (--ref) and
# renders version-specific ones from tools/bridge-template/ (@TOKENS@).
# Scope is deliberate: etages 1+2 pass without MC; etage 3 (live) is a
# placeholder that fails loudly until the live run is ported manually
# (pins cannot be templated — they are measured, never defaulted).
#
# Example:
#   sh tools/scaffold-bridge.sh --sfx 1201 --mc 1.20.1 --forge 47.2.0
#   sh tools/scaffold-bridge.sh --sfx 1709 --mc 1.7.10 --forge 10.13.4.1614 \
#     --forge-long 1.7.10-10.13.4.1614-1.7.10 --sink legacy --mapping srg
set -eu
HUB="$(dirname "$0")/.."
TPL="$HUB/tools/bridge-template"

usage() {
  sed -n '2,13p' "$0"
  echo "usage: scaffold-bridge.sh --sfx <sfx> --mc <mc> --forge <forge> [opts]"
  echo "  --forge-long <long>  default <mc>-<forge>"
  echo "  --forge-url <url>    default Maven installer for <forge-long>"
  echo "  --fml-pkg <pkg>      default net.minecraftforge.fml.common"
  echo "  --side-pkg <pkg>     default <fml-pkg minus .common>.relauncher"
  echo "  --dim-expr <expr>    default 'event.world.provider.getDimension()'"
  echo "  --sink <modern|legacy>  default modern (setBlockState)"
  echo "  --mapping <derive|srg>  default derive (no SRG file to mount)"
  echo "  --max-y <n>          default 255"
  echo "  --phase <L>          default D (tags <L>1/<L>2/<L>3)"
  echo "  --spi-pin <pin>      default: copy of --ref SPI_PIN (parity by construction)"
  echo "  --ref <dir>          default per --sink (../bridge-1122|../bridge-1710)"
  echo "  --out <dir>          default ../bridge-<sfx>"
  echo "  --dry-run            print plan, write nothing"
  echo "  --no-check           skip tools/check.sh in the new bridge"
}

SFX=""; MC=""; FORGE=""; FORGE_LONG=""; FORGE_URL=""
FML_PKG="net.minecraftforge.fml.common"
SIDE_PKG=""
DIM_EXPR="event.world.provider.getDimension()"
SINK="modern"; MAPPING="derive"; MAX_Y="255"; PHASE="D"
SPI_PIN="FROM_REF"; REF=""; OUT=""; DRY="0"; CHECK="1"

while [ $# -gt 0 ]; do
  case "$1" in
    --sfx) SFX="$2"; shift 2;;
    --mc) MC="$2"; shift 2;;
    --forge) FORGE="$2"; shift 2;;
    --forge-long) FORGE_LONG="$2"; shift 2;;
    --forge-url) FORGE_URL="$2"; shift 2;;
    --fml-pkg) FML_PKG="$2"; shift 2;;
    --side-pkg) SIDE_PKG="$2"; shift 2;;
    --dim-expr) DIM_EXPR="$2"; shift 2;;
    --sink) SINK="$2"; shift 2;;
    --mapping) MAPPING="$2"; shift 2;;
    --max-y) MAX_Y="$2"; shift 2;;
    --phase) PHASE="$2"; shift 2;;
    --spi-pin) SPI_PIN="$2"; shift 2;;
    --ref) REF="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --dry-run) DRY="1"; shift;;
    --no-check) CHECK="0"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "FAIL scaffold : unknown arg <$1> (see --help)"; exit 1;;
  esac
done

[ -n "$SFX" ] || { echo "FAIL scaffold : --sfx required (e.g. 1201)"; exit 1; }
[ -n "$MC" ] || { echo "FAIL scaffold : --mc required (e.g. 1.20.1)"; exit 1; }
[ -n "$FORGE" ] || { echo "FAIL scaffold : --forge required (e.g. 47.2.0)"; exit 1; }
case "$SFX" in *[!0-9]*) echo "FAIL scaffold : --sfx must be numeric (got <$SFX>)"; exit 1;; esac
case "$SINK" in modern|legacy) ;; *) echo "FAIL scaffold : --sink must be modern|legacy (got <$SINK>)"; exit 1;; esac
case "$MAPPING" in derive|srg) ;; *) echo "FAIL scaffold : --mapping must be derive|srg (got <$MAPPING>)"; exit 1;; esac
case "$PHASE" in ?) ;; *) echo "FAIL scaffold : --phase must be one letter (got <$PHASE>)"; exit 1;; esac
[ -d "$TPL" ] || { echo "FAIL scaffold : template dir <$TPL> absent"; exit 1; }

[ -n "$FORGE_LONG" ] || FORGE_LONG="$MC-$FORGE"
# Side lives beside .common, not under it (cpw.mods.fml.relauncher,
# net.minecraftforge.fml.relauncher) — derive unless overridden.
[ -n "$SIDE_PKG" ] || SIDE_PKG="$(printf '%s' "$FML_PKG" | sed 's/\.common$//').relauncher"
[ -n "$FORGE_URL" ] || FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/$FORGE_LONG/forge-$FORGE_LONG-installer.jar"
[ -n "$REF" ] || { if [ "$SINK" = "legacy" ]; then REF="$HUB/../bridge-1710"; else REF="$HUB/../bridge-1122"; fi; }
[ -n "$OUT" ] || OUT="$HUB/../bridge-$SFX"
[ -d "$REF" ] || { echo "FAIL scaffold : --ref <$REF> absent"; exit 1; }
if [ -e "$OUT" ]; then echo "FAIL scaffold : --out <$OUT> exists (refusing to overwrite)"; exit 1; fi
# Default pin is the ref bridge's pin verbatim (same form, same target):
# parity by construction. --spi-pin overrides deliberately (re-validate).
if [ "$SPI_PIN" = "FROM_REF" ]; then
  [ -f "$REF/SPI_PIN" ] || { echo "FAIL scaffold : <$REF/SPI_PIN> absent (cannot default pin)"; exit 1; }
  SPI_PIN=$(tr -d '[:space:]' < "$REF/SPI_PIN")
fi
[ -n "$SPI_PIN" ] || { echo "FAIL scaffold : empty SPI_PIN (pass --spi-pin or fix <$REF/SPI_PIN>)"; exit 1; }

P1="$PHASE""1"; P2="$PHASE""2"; P3="$PHASE""3"
LIVE_DIR="$P3"_DIR; OFFLINE="$P3"_OFFLINE; FAIL_TAG=$(echo "$P3" | tr 'A-Z' 'a-z')-live
LIVE_TAG_LOWER=$(echo "$P3" | tr 'A-Z' 'a-z')
REF_SFX=$(basename "$REF"); REF_SFX=${REF_SFX#bridge-}
if [ "$SINK" = "legacy" ]; then
  SINK_DESC="legacy edits (\`World.setBlock\`, int meta)"
else
  SINK_DESC="\`World.setBlockState\` + \`BlockPos\` + \`IBlockState\`"
fi
if [ "$MAPPING" = "derive" ]; then
  MAPPING_GUIDE="#   2. narrow MCP->SRG map derived in-run from pinned vanilla server +%%NL%%#      mappings (no ForgeGradle cache, no SRG file to mount).%%NL%%"
else
  MAPPING_GUIDE="#   2. SRG_MCP path (ForgeGradle cache under \$HOME, \$SRG_MCP override wins)%%NL%%#      + SRG sha1 pin; mount it into Docker like bridge-1710.%%NL%%"
fi

# sed-escape a replacement value (| is the delimiter; %%NL%% in a value
# becomes a newline via the trailing expression).
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
render() {
  sed -e "s|@SFX@|$(esc "$SFX")|g" \
      -e "s|@MC@|$(esc "$MC")|g" \
      -e "s|@FORGE@|$(esc "$FORGE")|g" \
      -e "s|@FORGE_LONG@|$(esc "$FORGE_LONG")|g" \
      -e "s|@FORGE_URL@|$(esc "$FORGE_URL")|g" \
      -e "s|@FML_PKG@|$(esc "$FML_PKG")|g" \
      -e "s|@SIDE_PKG@|$(esc "$SIDE_PKG")|g" \
      -e "s|@DIM_EXPR@|$(esc "$DIM_EXPR")|g" \
      -e "s|@MAX_Y@|$(esc "$MAX_Y")|g" \
      -e "s|@PHASE@|$(esc "$PHASE")|g" \
      -e "s|@P1@|$(esc "$P1")|g" \
      -e "s|@P2@|$(esc "$P2")|g" \
      -e "s|@P3@|$(esc "$P3")|g" \
      -e "s|@LIVE_DIR@|$(esc "$LIVE_DIR")|g" \
      -e "s|@OFFLINE@|$(esc "$OFFLINE")|g" \
      -e "s|@FAIL_TAG@|$(esc "$FAIL_TAG")|g" \
      -e "s|@LIVE_TAG_LOWER@|$(esc "$LIVE_TAG_LOWER")|g" \
      -e "s|@REF_SFX@|$(esc "$REF_SFX")|g" \
      -e "s|@SINK@|$(esc "$SINK")|g" \
      -e "s|@SINK_DESC@|$(esc "$SINK_DESC")|g" \
      -e "s|@SPI_PIN@|$(esc "$SPI_PIN")|g" \
      -e "s|@MAPPING_GUIDE@|$(esc "$MAPPING_GUIDE")|g" \
      -e 's/%%NL%%/\
/g' "$1"
}

if [ "$DRY" = "1" ]; then
  echo "plan bridge-$SFX (mc $MC, forge $FORGE_LONG, sink $SINK, mapping $MAPPING, ref $REF, pin $SPI_PIN)"
  echo "  render: MatouBridgeMod.java PackWire.java WorldCellSink-$SINK.java check.sh run-live.sh Dockerfile README.md CHANGELOG.md check.yml live-proof.yml"
  echo "  copy: AGENTS.md .gitignore LICENSE ForgeContentCheck.java anvil.py CellUnion.java Reobf.java stub/ run-client.sh verify-client-save.sh (hub wrappers)"
  echo "  out: $OUT"
  exit 0
fi

FSRC="$OUT/forge/src/fr/iamacat/bridge/forge"
mkdir -p "$FSRC" "$OUT/java/test/fr/iamacat/bridge" "$OUT/tools/live" \
  "$OUT/.github/workflows"

render "$TPL/MatouBridgeMod.java.tpl" > "$FSRC/MatouBridgeMod.java"
render "$TPL/PackWire.java.tpl" > "$FSRC/PackWire.java"
render "$TPL/WorldCellSink-$SINK.java.tpl" > "$FSRC/WorldCellSink.java"
render "$TPL/check.sh.tpl" > "$OUT/tools/check.sh"
render "$TPL/run-live-placeholder.sh.tpl" > "$OUT/tools/run-live.sh"
render "$TPL/Dockerfile.tpl" > "$OUT/tools/live/Dockerfile"
render "$TPL/README.md.tpl" > "$OUT/README.md"
render "$TPL/CHANGELOG.md.tpl" > "$OUT/CHANGELOG.md"
render "$TPL/check.yml.tpl" > "$OUT/.github/workflows/check.yml"
render "$TPL/live-proof.yml.tpl" > "$OUT/.github/workflows/live-proof.yml"
printf '%s\n' "$SPI_PIN" > "$OUT/SPI_PIN"

for f in AGENTS.md .gitignore LICENSE; do
  [ -f "$REF/$f" ] || { echo "FAIL scaffold : ref file <$REF/$f> absent"; exit 1; }
  cp "$REF/$f" "$OUT/$f"
done
for f in tools/live/anvil.py tools/live/CellUnion.java tools/live/Reobf.java \
  tools/run-client.sh tools/verify-client-save.sh \
  java/test/fr/iamacat/bridge/ForgeContentCheck.java; do
  [ -f "$REF/$f" ] || { echo "FAIL scaffold : ref file <$REF/$f> absent"; exit 1; }
  cp "$REF/$f" "$OUT/$f"
done
[ -d "$REF/tools/live/stub" ] || { echo "FAIL scaffold : ref stubs <$REF/tools/live/stub> absent"; exit 1; }
cp -r "$REF/tools/live/stub" "$OUT/tools/live/stub"

# Retarget the copied E2E header from the ref phase to the new one.
sed -i -e "s/same pattern as B2 in bridge-1710/bridge-$REF_SFX pattern/" \
  -e "s/Body kept in sync with bridge-1710's copy by/Body kept in sync with the other bridges by/" \
  -e "s/C2 end-to-end gate/$P2 end-to-end gate/" \
  "$OUT/java/test/fr/iamacat/bridge/ForgeContentCheck.java"

chmod +x "$OUT/tools/check.sh" "$OUT/tools/run-live.sh" \
  "$OUT/tools/run-client.sh" "$OUT/tools/verify-client-save.sh"

if grep -r "@[A-Z_]*@" "$OUT" --include='*' -l | grep -v build/ | head -n 5 | grep -q .; then
  echo "FAIL scaffold : unrendered @TOKEN@ left in $OUT"
  grep -rn "@[A-Z_]*@" "$OUT" | head -n 10 || true
  exit 1
fi

echo "ok (scaffold bridge-$SFX at $OUT, pin $SPI_PIN)"
echo "next: create matou-dev/bridge-$SFX, add its NAMES.md row, run sh tools/check.sh (etages 1+2), port live for $P3"

if [ "$CHECK" = "1" ]; then
  if [ -d "$OUT/../spi/java/src" ] && [ -d "$OUT/../example1/java/src" ]; then
    sh "$OUT/tools/check.sh"
  else
    echo "skip check (no spi/example1 siblings next to $OUT)"
  fi
fi
