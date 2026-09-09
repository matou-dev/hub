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
HUB_ABS="$(cd "$(dirname "$0")" && pwd)"
cd "$BRIDGE"
VERSION="${VERSION:-0.0-dev}"
PRISM_DIR="${PRISM_DIR:-$HOME/.local/share/PrismLauncher}"
PRISM_BIN="${PRISM_BIN:-prismlauncher}"
# Never touch the user's live Prism home: automated runs stage into
# isolated roots only (a launch without -d once rewrote accounts.json).
case "${PRISM_DIR%/}" in
  "$HOME/.local/share/PrismLauncher")
    echo "FAIL run-client : PRISM_DIR is the live user dir ($HOME/.local/share/PrismLauncher)"
    echo "fix: point PRISM_DIR at an isolated root (e.g. \${TMPDIR:-/tmp}/matou-<tag>-prism)"; exit 1;;
esac

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

# 1b. Autoplay companion (DEV ONLY, AUTOPLAY=1): derive the companion
#     narrow map from the pinned vanilla CLIENT jar + joined.tsrg (same
#     javap/tsrg practice as the live derive, but DEV-scoped: the live
#     srg-narrow.srg is never touched), pin every WANT line plus the
#     bridge universal-pin.txt Forge surface, then build + reobf the
#     companion. Bridge owns tools/autoplay/{want.txt,client-pin.txt,
#     universal-pin.txt,src,stub,autoplay-mods.toml,preseed.py}; hub owns
#     this machinery. Absent want.txt = bridge without autoplay: loud.
HAVE_AUTOPLAY=0
if [ "${AUTOPLAY:-}" = "1" ]; then
  [ -f tools/autoplay/want.txt ] \
    || { echo "FAIL run-client : no autoplay WANT (tools/autoplay/want.txt absent in $BRIDGE)"; exit 1; }
  [ -f tools/autoplay/client-pin.txt ] && [ -f tools/autoplay/universal-pin.txt ] \
    || { echo "FAIL run-client : tools/autoplay/{client-pin,universal-pin}.txt absent in $BRIDGE"; exit 1; }
  UP="$CLIENT_DIR/upstream"
  mkdir -p "$UP"
  PIN_URL="$(sed -n 's/^URL=//p' tools/autoplay/client-pin.txt)"
  PIN_SHA1="$(sed -n 's/^SHA1=//p' tools/autoplay/client-pin.txt)"
  [ -n "$PIN_URL" ] && [ -n "$PIN_SHA1" ] \
    || { echo "FAIL run-client : malformed tools/autoplay/client-pin.txt (want URL= + SHA1=)"; exit 1; }
  if [ ! -f "$UP/client.jar" ] || ! echo "$PIN_SHA1  $UP/client.jar" | sha1sum -c - >/dev/null 2>&1; then
    echo "note run-client : fetching pinned vanilla client (network once, $PIN_SHA1)"
    rm -f "$UP/client.jar"
    curl -sL -o "$UP/client.jar" "$PIN_URL" \
      || { echo "FAIL run-client : client jar download failed"; exit 1; }
    echo "$PIN_SHA1  $UP/client.jar" | sha1sum -c - >/dev/null 2>&1 \
      || { echo "FAIL run-client : client jar sha1 drift (want $PIN_SHA1, never silent upgrade)"; exit 1; }
  fi
  echo "ok run-client : pinned vanilla client ($PIN_SHA1)"
  MCP_ZIP=$(find "$LIVE_DIR" -maxdepth 1 -name "mcp_config*.zip" | head -n 1 || true)
  [ -n "$MCP_ZIP" ] \
    || { echo "FAIL run-client : no mcp_config*.zip in <$LIVE_DIR> (run tools/run-live.sh once first)"; exit 1; }
  SNAP_ZIP=$(find "$LIVE_DIR" -maxdepth 1 -name "mcp_snapshot*.zip" | head -n 1 || true)
  if [ ! -f "$UP/joined.tsrg" ]; then
    rm -rf "$UP/mcp" && mkdir -p "$UP/mcp"
    unzip -o -q "$MCP_ZIP" -d "$UP/mcp" "config/joined.tsrg" \
      || { echo "FAIL run-client : cannot extract joined.tsrg from <$MCP_ZIP>"; exit 1; }
    cp "$UP/mcp/config/joined.tsrg" "$UP/joined.tsrg"
    if [ -n "$SNAP_ZIP" ]; then
      unzip -o -q "$SNAP_ZIP" -d "$UP/mcp" "fields.csv" "methods.csv" \
        || { echo "FAIL run-client : cannot extract snapshot csvs from <$SNAP_ZIP>"; exit 1; }
    fi
  fi
  UNI=$(find "$LIVE_DIR/server/libraries" -name "forge-*-universal.jar" 2>/dev/null | head -n 1 || true)
  # mcmod.info era (LaunchWrapper): the old installer lays the universal at
  # the server root (forge-1.12.2-*.jar, no -universal suffix) instead of
  # server/libraries — same bytes run-live.sh pins as $UNI there.
  if [ -z "$UNI" ]; then
    UNI=$(find "$LIVE_DIR/server" -maxdepth 1 -name "forge-1*.jar" ! -name "*installer*" 2>/dev/null | head -n 1 || true)
  fi
  [ -n "$UNI" ] \
    || { echo "FAIL run-client : no forge universal under <$LIVE_DIR/server> (run tools/run-live.sh once first)"; exit 1; }
  while read -r cls pat; do
    [ -n "$cls" ] || continue
    case "$cls" in \#*) continue;; esac
    "$JB/javap" -p -cp "$UNI" "$cls" 2>/dev/null | grep -q "$pat" \
      || { echo "FAIL run-client : universal pin unmet <$cls :: $pat>"; exit 1; }
  done < tools/autoplay/universal-pin.txt
  echo "ok run-client : companion Forge surface pinned to universal"
  SRG_AUTO="$CLIENT_DIR/autoplay-narrow.srg"
  "$JB/javap" -version >/dev/null 2>&1 || { echo "FAIL run-client : no javap next to <$JB>"; exit 1; }
  # Mojmap era (client-mappings-pin.txt present, e.g. 1201): the narrow map
  # derives from the official CLIENT mappings + joined.tsrg v2 — same join
  # as the D3 live derive in the bridge run-live.sh (which uses server.txt
  # for server members; client members need the client map). MCP era keeps
  # the historical joined.tsrg-v1 (+ optional snapshot) path below.
  if [ -f tools/autoplay/client-mappings-pin.txt ]; then
    MAP_URL="$(sed -n 's/^URL=//p' tools/autoplay/client-mappings-pin.txt)"
    MAP_SHA1="$(sed -n 's/^SHA1=//p' tools/autoplay/client-mappings-pin.txt)"
    [ -n "$MAP_URL" ] && [ -n "$MAP_SHA1" ] \
      || { echo "FAIL run-client : malformed tools/autoplay/client-mappings-pin.txt (want URL= + SHA1=)"; exit 1; }
    if [ ! -f "$UP/client.txt" ] || ! echo "$MAP_SHA1  $UP/client.txt" | sha1sum -c - >/dev/null 2>&1; then
      echo "note run-client : fetching pinned client mappings (network once, $MAP_SHA1)"
      rm -f "$UP/client.txt"
      curl -sL -o "$UP/client.txt" "$MAP_URL" \
        || { echo "FAIL run-client : client mappings download failed"; exit 1; }
      echo "$MAP_SHA1  $UP/client.txt" | sha1sum -c - >/dev/null 2>&1 \
        || { echo "FAIL run-client : client mappings sha1 drift (want $MAP_SHA1, never silent upgrade)"; exit 1; }
    fi
    echo "ok run-client : pinned client mappings ($MAP_SHA1)"
    python3 - "$UP/joined.tsrg" "$UP/client.txt" "tools/autoplay/want.txt" "$SRG_AUTO" "$JB/javap" "$UP/client.jar" <<'EOF'
import sys, subprocess, re
tsrg, mojmaps, wantf, outpath, javap, client = sys.argv[1:7]
# client.txt: moj class (dots) -> obf class; members (kind, rettype, name, args, obf).
moj2obf, members = {}, {}
cur = None
for raw in open(mojmaps):
    if not raw.strip() or raw.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        m = re.match(r"^\s+(?:\d+:\d+:)?(\S+) ([\w$<>]+)(\(.*\))? -> ([\w$<>]+)$", raw.rstrip())
        assert m, "E_AUTO_DERIVE:unparsed mappings line <%s>" % raw.rstrip()
        rettype, name, args, obf = m.groups()
        kind = "method" if args is not None else "field"
        members.setdefault(cur, []).append((kind, rettype, name, args or "", obf))
    else:
        if "package-info -> " in raw:
            continue
        m = re.match(r"^([\w.$]+) -> ([\w$.]+):$", raw.rstrip())
        assert m, "E_AUTO_DERIVE:unparsed mappings class <%s>" % raw.rstrip()
        cur = m.group(1)
        moj2obf[cur] = m.group(2)
        members.setdefault(cur, [])
def to_internal(moj_dots):
    return moj_dots.replace(".", "/")
def obf_desc(moj_desc):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + to_internal(moj2obf.get(m.group(1).replace("/", "."), m.group(1))) + ";",
                  moj_desc)
# TSRG v2 (same shape as the D3 live derive): class lines `obf srg [id]`;
# member lines (one tab) `obf [desc] srg [id]`, `static` (two tabs) after.
obf2srg, classes = {}, {}
cur = None
for raw in open(tsrg).read().splitlines():
    if not raw.strip() or raw.startswith("tsrg2"):
        continue
    if raw[0] in (" ", "\t"):
        s = raw.strip()
        if s == "static":
            classes[cur][-1]["static"] = True
            continue
        if re.match(r"^\d+ ", s):
            continue
        parts = s.split()
        if "(" in s:
            classes[cur].append({"obf": parts[0], "desc": parts[1], "srg": parts[2], "static": False})
        else:
            classes[cur].append({"obf": parts[0], "desc": None, "srg": parts[1], "static": False})
    else:
        obf, srg = raw.split()[:2]
        obf2srg[obf] = srg
        cur = obf
        classes.setdefault(cur, [])
def srg_desc(obf_d):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + obf2srg.get(m.group(1), m.group(1)) + ";",
                  obf_d)
def javap_flags(cls):
    out = subprocess.check_output([javap, "-p", "-s", "-cp", client, cls]).decode()
    res, name, static = {}, None, False
    for l in out.splitlines():
        s = l.strip()
        if s.startswith("descriptor:"):
            res[(name, s.split(None, 1)[1])] = static
        elif s and not s.startswith("Compiled"):
            m = re.match(r".*\s([\w$<>]+)\(", s)
            if m:
                static = bool(re.search(r"\bstatic\b", s.split("(")[0]))
                name = m.group(1)
            elif "(" not in s and s.endswith(";") and "{" not in s:
                m2 = re.match(r"(?:(.*)\s)?([\w.$\[\]<>, ?&]+?)\s+([\w$]+);", s)
                assert m2, "E_AUTO_DERIVE:unparsed javap line <%s> in <%s>" % (s, cls)
                static = bool(re.search(r"\bstatic\b", m2.group(1) or ""))
                name = m2.group(3)
                res[(name, "F:" + re.sub(r"<.*>", "", m2.group(2)))] = static
    return res
PRIM = {"B": "byte", "C": "char", "D": "double", "F": "float",
        "I": "int", "J": "long", "S": "short", "Z": "boolean", "V": "void"}
def desc_args(desc):
    body = desc[desc.index("(") + 1:desc.index(")")]
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == "L":
            j = body.index(";", i)
            out.append(body[i + 1:j].replace("/", "."))
            i = j + 1
        elif c == "[":
            j = i
            while body[j] == "[":
                j += 1
            if body[j] == "L":
                k = body.index(";", j)
                out.append(body[j + 1:k].replace("/", ".") + "[]" * (j - i))
                i = k + 1
            else:
                out.append(PRIM[body[j]] + "[]" * (j - i))
                i = j + 1
        else:
            out.append(PRIM[c])
            i += 1
    return out
def norm_args(a):
    a = a.strip()
    assert a.startswith("(") and a.endswith(")"), "E_AUTO_DERIVE:bad args <%s>" % a
    return [x for x in a[1:-1].split(",") if x]
lines = []
for raw in open(wantf):
    raw = raw.strip()
    if not raw or raw.startswith("#"):
        continue
    kind, owner, moj, srg_want, desc, want_static = raw.split()
    assert kind == "M", "E_AUTO_DERIVE:only M lines supported (got <%s>)" % raw
    want_static = want_static == "1"
    moj_cls = owner.replace("/", ".")
    obf_owner = moj2obf[moj_cls]
    want_args = desc_args(desc)
    cands = [(k, r, n, a, o) for (k, r, n, a, o) in members[moj_cls]
             if k == "method" and n == moj and norm_args(a) == want_args]
    assert len(cands) == 1, "E_AUTO_DERIVE:mojmap member <%s %s%s> %s" % (owner, moj, desc, cands)
    obf_name = cands[0][4]
    od = obf_desc(desc)
    tm = [m for m in classes[obf_owner] if m["desc"] == od and m["obf"] == obf_name]
    assert len(tm) == 1, "E_AUTO_DERIVE:no tsrg member <%s %s %s>" % (obf_owner, obf_name, od)
    # The SRG column is load-bearing, not documentary: re-derived, then
    # compared — a stale want.txt fails here, never at runtime.
    assert tm[0]["srg"] == srg_want, "E_AUTO_DERIVE:srg drift <%s> is <%s>, want <%s>" % (moj, tm[0]["srg"], srg_want)
    flags = javap_flags(obf_owner)
    assert flags.get((obf_name, od)) == want_static, \
        "E_AUTO_DERIVE:javap mismatch <%s %s> %s" % (obf_owner, obf_name, flags.get((obf_name, od)))
    sd = srg_desc(od)
    # LEFT slot is SRG, not obf: Reobf maps Mojmap->LEFT, same shape as
    # the live srg-narrow.srg (Mojmap sources run against an SRG runtime).
    lines.append("MD: %s/%s %s %s/%s %s" % (obf2srg[obf_owner], tm[0]["srg"], sd, owner, moj, desc))
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok autoplay-derive : narrow SRG derived (%d lines, mojmap)" % len(lines))
EOF
  else
    python3 - "$UP/joined.tsrg" "$UP/mcp/fields.csv" "$UP/mcp/methods.csv" "tools/autoplay/want.txt" "$SRG_AUTO" "$JB/javap" "$UP/client.jar" <<'EOF'
import sys, subprocess, csv, re
tsrg, fcsv, mcsv, wantf, outpath, javap, client = sys.argv[1:8]
srg2obf, classes = {}, {}
cur = None
for raw in open(tsrg).read().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        classes.setdefault(cur, []).append(line.split())
    else:
        obf, srg = line.split()
        srg2obf[srg] = obf
        cur = srg
snap_m, snap_f = {}, {}
try:
    for row in csv.DictReader(open(mcsv)):
        snap_m[row["searge"]] = row["name"]
    for row in csv.DictReader(open(fcsv)):
        snap_f[row["searge"]] = row["name"]
except IOError:
    pass
def obf_desc(d):
    return re.sub(r"L([^;]+);", lambda m: "L" + srg2obf.get(m.group(1), m.group(1)) + ";", d)
def javap_flags(cls):
    out = subprocess.check_output([javap, "-p", "-s", "-cp", client, cls]).decode()
    res, name, static = {}, None, False
    for l in out.splitlines():
        s = l.strip()
        if s.startswith("descriptor:"):
            res[(name, s.split(None, 1)[1])] = static
        elif s and not s.startswith("Compiled"):
            m = re.match(r".*\s([\w$<>]+)\(", s)
            if m:
                static = bool(re.search(r"\bstatic\b", s.split("(")[0]))
                name = m.group(1)
            elif "(" not in s and s.endswith(";") and "{" not in s:
                # Field type class carries ? and & too: 1.12.2-era javap
                # prints wildcard bounds (e.g. Queue<FutureTask<?>>), which
                # the 1165-era class rejected loudly (C3 autoplay derive).
                m2 = re.match(r"(?:(.*)\s)?([\w.$\[\]<>, ?&]+?)\s+([\w$]+);", s)
                assert m2, "E_AUTO_DERIVE:unparsed javap line <%s> in <%s>" % (s, cls)
                static = bool(re.search(r"\bstatic\b", m2.group(1) or ""))
                name = m2.group(3)
                res[(name, "F:" + re.sub(r"<.*>", "", m2.group(2)))] = static
    return res
lines = []
for raw in open(wantf):
    raw = raw.strip()
    if not raw or raw.startswith("#"):
        continue
    kind, owner, mcp, srg_want, desc, want_static = raw.split()
    want_static = want_static == "1"
    obf_owner = srg2obf[owner]
    members = classes[owner]
    if kind == "M":
        od = obf_desc(desc)
        cands = [(mm[0], mm[2]) for mm in members if len(mm) == 3 and mm[1] == od]
        assert cands, "E_AUTO_DERIVE:no tsrg member <%s %s>" % (owner, mcp)
        flags = javap_flags(obf_owner)
        hits = [(n, s) for n, s in cands if flags.get((n, od)) == want_static and s == srg_want]
        assert len(hits) == 1, "E_AUTO_DERIVE:unresolved <%s %s %s> %s" % (owner, mcp, srg_want, hits)
        srg_name = hits[0][1]
        if snap_m:
            assert snap_m.get(srg_name) == mcp, "E_AUTO_DERIVE:snapshot lock <%s> is <%s>, want <%s>" % (srg_name, snap_m.get(srg_name), mcp)
        # LEFT slot is SRG, not obf: Reobf maps MCP->LEFT, same shape as
        # the live srg-narrow.srg (MCP sources run against an SRG runtime).
        lines.append("MD: %s/%s %s %s/%s %s" % (owner, srg_name, desc, owner, mcp, desc))
    else:
        raise SystemExit("E_AUTO_DERIVE:only M lines supported (got <%s>)" % raw)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok autoplay-derive : narrow SRG derived (%d lines)" % len(lines))
EOF
  fi
  [ "$(grep -c . "$SRG_AUTO")" = "$(grep -cv -e '^#' -e '^$' tools/autoplay/want.txt)" ] \
    || { echo "FAIL run-client : autoplay narrow map drift (want $(grep -cv -e '^#' -e '^$' tools/autoplay/want.txt) lines)"; exit 1; }
  echo "ok run-client : companion narrow map pinned ($SRG_AUTO)"
  mkdir -p "$BLD/auto" "$BLD/autoplaymod/META-INF"
  "$JB/javac" $JFLAGS -nowarn -cp "$BLD/spi" -d "$BLD/auto" $(find tools/autoplay/src tools/autoplay/stub tools/live/stub -name '*.java')
  # Companion metadata follows the bridge era, like the bridge jar itself:
  # mods.toml era stamps autoplay-mods.toml, mcmod.info era stamps
  # autoplay-mcmod.info (absent file = bridge without companion metadata,
  # loud — never a silent wrong-era default).
  if [ "$MODS_STYLE" = "mods.toml" ]; then
    [ -f tools/autoplay/autoplay-mods.toml ] \
      || { echo "FAIL run-client : tools/autoplay/autoplay-mods.toml absent in $BRIDGE"; exit 1; }
    sed "s/@VERSION@/$VERSION/g" tools/autoplay/autoplay-mods.toml > "$BLD/autoplaymod/META-INF/mods.toml"
    AUTO_META="mods.toml"
  else
    [ -f tools/autoplay/autoplay-mcmod.info ] \
      || { echo "FAIL run-client : tools/autoplay/autoplay-mcmod.info absent in $BRIDGE"; exit 1; }
    sed "s/@VERSION@/$VERSION/g" tools/autoplay/autoplay-mcmod.info > "$BLD/autoplaymod/mcmod.info"
    AUTO_META="mcmod.info"
  fi
  rm -rf "$BLD/autoplaystage" && mkdir -p "$BLD/autoplaystage"
  mkdir -p "$BLD/autoplaystage/fr"
  cp -r "$BLD/auto/fr/"* "$BLD/autoplaystage/fr/"
  [ -e "$BLD/autoplaystage/net" ] && { echo "FAIL run-client : stub leak into autoplay jar"; exit 1; }
  if [ "$AUTO_META" = "mods.toml" ]; then
    mkdir -p "$BLD/autoplaystage/META-INF"
    cp "$BLD/autoplaymod/META-INF/mods.toml" "$BLD/autoplaystage/META-INF/mods.toml"
  else
    cp "$BLD/autoplaymod/mcmod.info" "$BLD/autoplaystage/mcmod.info"
  fi
  mkjar "$BLD/jars/matouautoplay.jar" "$BLD/autoplaystage"
  "$JB/javac" -nowarn -cp "$REOBF_CP" -d "$BLD" tools/live/Reobf.java
  "$JB/java" -cp "$BLD:$REOBF_CP" Reobf "$SRG_AUTO" "$BLD/jars/matouautoplay.jar" "$BLD/jars/matouautoplay-reobf.jar"
  normjar "$BLD/jars/matouautoplay-reobf.jar"
  echo "ok run-client : autoplay companion built (DEV-only, never in dist/)"
  HAVE_AUTOPLAY=1
fi

# 2. Prism instance (MultiMC format, as proven by local Prism 11 instances:
#    instance.cfg + mmc-pack.json + minecraft/ game dir).
IDIR="$PRISM_DIR/instances/$INST"
mkdir -p "$IDIR/minecraft/mods" "$IDIR/minecraft/config/matoubridge"
# Headless-proof game dir: singleplayer auto-pauses on lost focus, and
# under Xvfb the window never owns the focus — the integrated server then
# stops ticking seconds after join and the automated proof dies by timeout
# (measured on 1122: 1 world tick played, regions untouched after the pause
# flush). Pin pauseOnLostFocus:false (create or amend, never clobber the
# rest of a dev's file).
OPT="$IDIR/minecraft/options.txt"
if [ -f "$OPT" ]; then
  if grep -q "^pauseOnLostFocus:true" "$OPT"; then
    sed -i 's/^pauseOnLostFocus:true/pauseOnLostFocus:false/' "$OPT"
    echo "note run-client : pinned pauseOnLostFocus:false in existing options.txt (headless proof)"
  elif ! grep -q "^pauseOnLostFocus:" "$OPT"; then
    printf 'pauseOnLostFocus:false\n' >> "$OPT"
    echo "note run-client : appended pauseOnLostFocus:false to options.txt (headless proof)"
  fi
else
  printf 'pauseOnLostFocus:false\n' > "$OPT"
  echo "note run-client : seeded options.txt with pauseOnLostFocus:false (headless proof)"
fi
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
if [ "${HAVE_AUTOPLAY:-0}" = "1" ]; then
  cp "$BLD/jars/matouautoplay-reobf.jar" "$IDIR/minecraft/mods/matouautoplay.jar"
  echo "ok run-client : autoplay companion staged (DEV-only, never in dist/)"
fi
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
WORLD="${AUTOPLAY_WORLD:-matou}"
export AUTOPLAY_WORLD="$WORLD"
OFFLINE_NAME="${OFFLINE_NAME:-MatouDev}"
if [ "${HAVE_AUTOPLAY:-0}" = "1" ]; then
  # Fresh proof every automated run: reset the world, then preseed flat.
  # (Manual varied-hut dev keeps the kept-packs.cfg flow above by running
  # without AUTOPLAY.) Refuses loudly when the save cannot be written.
  python3 tools/autoplay/preseed.py "$GDIR/saves" "$WORLD" \
    || { echo "FAIL run-client : preseed failed"; exit 1; }
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
