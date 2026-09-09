#!/bin/sh
# run-client-direct.sh — Prism-free automated client proof (DEV ONLY, NOT a gate).
#
# Plays the staged dev-client instance without any launcher: the official
# Forge installer provisions the vanilla + Forge client runtime once
# (pinned bytes, cached), then plain java replays the production
# ModLauncher invocation headless under xvfb-run. No Prism process ever
# runs here (no accounts, no wizard, no Qt, no Wayland leak by
# construction) — Prism stays a manual-dev convenience only.
#
# Flow (two commands, zero duplicated staging):
#   1. AUTOPLAY=1 PRISM_DIR=<iso> sh hub/tools/run-client.sh --bridge <dir>
#      stages DEV jars + content + packs.cfg and preseeds a fresh world.
#   2. PRISM_DIR=<same-iso> sh hub/tools/run-client-direct.sh --bridge <dir>
#      provisions the client runtime (once), plays, then replays the live
#      verdict on the save (world == pure union).
#
# Env (no machine paths hardcoded):
#   PRISM_DIR  isolated root holding the staged instance (same value as
#              step 1; the live Prism home is refused loudly, as in
#              run-client.sh).
#   AUTOPLAY_WORLD  proof world name (default matou; same default as the
#              companion mod and run-client.sh preseed — override in both
#              steps together or not at all).
#   OFFLINE_NAME    offline player (default MatouDev, deterministic UUID).
#   VERIFY=0    skip the post-play verdict replay (default: verify).
#   JAVA_XMX    game heap (default 2G).
# Fails loudly (never silently): unstaged instance, installer sha1 drift
# vs the bridge run-live.sh pin, vanilla json drift, missing library /
# asset / native, game crash. The verdict owns the exit status.
set -eu
if [ "${1:-}" = "--bridge" ]; then BRIDGE="${2:-}"; shift 2; fi
[ $# = "0" ] || { echo "FAIL run-direct : unknown arg <$1> (want [--bridge <dir>]; env carries the rest)"; exit 1; }
. "$(dirname "$0")/client-common.sh"
HUB_TOOLS="$(cd "$(dirname "$0")" && pwd)"
cd "$BRIDGE"
case "$SFX" in
  1165|1122|1201) ;;
  *) echo "FAIL run-direct : bridge <$SFX> has no measured client pins (provision once, pin, extend the table below)"; exit 1;;
esac
PRISM_DIR="${PRISM_DIR:-$HOME/.local/share/PrismLauncher}"
case "${PRISM_DIR%/}" in
  "$HOME/.local/share/PrismLauncher")
    echo "FAIL run-direct : PRISM_DIR is the live user dir ($HOME/.local/share/PrismLauncher)"
    echo "fix: point PRISM_DIR at the same isolated root used for staging"; exit 1;;
esac
# Measured vanilla version jsons (piston-meta manifest v2, never silent
# upgrade — one row per proven SFX, extended version by version):
case "$SFX" in
  1165)
    VANILLA_JSON_URL="https://piston-meta.mojang.com/v1/packages/fba9f7833e858a1257d810d21a3a9e3c967f9077/1.16.5.json"
    VANILLA_JSON_SHA1="fba9f7833e858a1257d810d21a3a9e3c967f9077";;
  1122)
    VANILLA_JSON_URL="https://piston-meta.mojang.com/v1/packages/832d95b9f40699d4961394dcf6cf549e65f15dc5/1.12.2.json"
    VANILLA_JSON_SHA1="832d95b9f40699d4961394dcf6cf549e65f15dc5";;
  1201)
    VANILLA_JSON_URL="https://piston-meta.mojang.com/v1/packages/f54b1a9b7e7fe6044f7f6525f1eddfe40ee771e1/1.20.1.json"
    VANILLA_JSON_SHA1="f54b1a9b7e7fe6044f7f6525f1eddfe40ee771e1";;
esac
FORGE_ID="$MC-forge-$FORGE_COMP"
GDIR="$PRISM_DIR/instances/$INST/minecraft"
[ -f "$GDIR/mods/matoubridge.jar" ] \
  || { echo "FAIL run-direct : unstaged game dir ($GDIR/mods/matoubridge.jar absent; run AUTOPLAY=1 run-client.sh first)"; exit 1; }
command -v xvfb-run >/dev/null \
  || { echo "FAIL run-direct : xvfb-run absent (this script is headless-only)"; exit 1; }
"$JB/java" -version >/dev/null 2>&1 || { echo "FAIL run-direct : no java under <$JB>"; exit 1; }

# 1. Pinned Forge installer (owned + pinned by the bridge run-live.sh; this
#    script never downloads it, only reuses the provisioned bytes).
INSTALLER_PIN="$(sed -n 's/^INSTALLER_SHA1="//p' tools/run-live.sh | cut -d'"' -f1)"
[ -n "$INSTALLER_PIN" ] \
  || { echo "FAIL run-direct : no INSTALLER_SHA1 pin in tools/run-live.sh (bridge owns it)"; exit 1; }
INSTALLER="$LIVE_DIR/forge-installer.jar"
[ -f "$INSTALLER" ] \
  || { echo "FAIL run-direct : installer absent ($INSTALLER; run tools/run-live.sh once first)"; exit 1; }
echo "$INSTALLER_PIN  $INSTALLER" | sha1sum -c - >/dev/null 2>&1 \
  || { echo "FAIL run-direct : installer sha1 drift (want $INSTALLER_PIN, never silent upgrade)"; exit 1; }
echo "ok run-direct : Forge installer pinned ($INSTALLER_PIN)"

# 2. Client runtime provision (once, cached in the game dir): the official
#    installer lays down libraries/ + versions/. It demands a launcher
#    profile file, so a minimal one is seeded (vanilla shape, no accounts).
UP="$CLIENT_DIR/direct-upstream"
mkdir -p "$UP"
VJSON="$UP/$MC.json"
if [ ! -f "$VJSON" ] || ! echo "$VANILLA_JSON_SHA1  $VJSON" | sha1sum -c - >/dev/null 2>&1; then
  echo "note run-direct : fetching pinned vanilla json (network once)"
  rm -f "$VJSON"
  curl -sL -o "$VJSON" "$VANILLA_JSON_URL" \
    || { echo "FAIL run-direct : vanilla json download failed"; exit 1; }
  echo "$VANILLA_JSON_SHA1  $VJSON" | sha1sum -c - >/dev/null 2>&1 \
    || { echo "FAIL run-direct : vanilla json sha1 drift (want $VANILLA_JSON_SHA1)"; exit 1; }
fi
if [ ! -f "$GDIR/launcher_profiles.json" ]; then
  printf '{"profiles":{"(Default)":{"name":"(Default)","type":"latest-release"}},"selectedProfile":"(Default)","clientToken":"00000000-0000-4000-8000-000000000000","authenticationDatabase":{},"launcherVersion":{"name":"2.1.0","format":21}}' > "$GDIR/launcher_profiles.json"
  echo "note run-direct : seeded minimal launcher profile (vanilla shape, no accounts)"
fi
if [ ! -f "$GDIR/versions/$FORGE_ID/$FORGE_ID.json" ]; then
  echo "note run-direct : installing client runtime (network once, official installer)"
  "$JB/java" -Djava.awt.headless=true -jar "$INSTALLER" --installClient "$GDIR" >/tmp/matou-direct-install.log 2>&1 \
    || { echo "FAIL run-direct : --installClient (see /tmp/matou-direct-install.log)"; exit 1; }
  [ -f "$GDIR/versions/$FORGE_ID/$FORGE_ID.json" ] \
    || { echo "FAIL run-direct : installer finished without $FORGE_ID.json (see /tmp/matou-direct-install.log)"; exit 1; }
fi
echo "ok run-direct : client runtime provisioned ($FORGE_ID)"

# 3. Assets (addressed by sha1 from the pinned json: every file self-pins,
#    missing-only download).
ASSET_INDEX="$(python3 - "$VJSON" <<'EOF'
import json, sys
print(json.load(open(sys.argv[1]))["assetIndex"]["id"])
EOF
)"
python3 - "$VJSON" "$GDIR" <<'EOF'
import json, os, sys, urllib.request
vjson, gdir = sys.argv[1:3]
v = json.load(open(vjson))
ai = v["assetIndex"]
os.makedirs(os.path.join(gdir, "assets", "indexes"), exist_ok=True)
idx_path = os.path.join(gdir, "assets", "indexes", ai["id"] + ".json")
if not os.path.isfile(idx_path):
    print("note run-direct : fetching asset index (network once)")
    urllib.request.urlretrieve(ai["url"], idx_path)
idx = json.load(open(idx_path))
n = 0
for name, o in idx["objects"].items():
    h = o["hash"]
    p = os.path.join(gdir, "assets", "objects", h[:2], h)
    if os.path.isfile(p) and os.path.getsize(p) == o["size"]:
        continue
    os.makedirs(os.path.dirname(p), exist_ok=True)
    urllib.request.urlretrieve("https://resources.download.minecraft.net/" + h[:2] + "/" + h, p)
    n += 1
print("ok run-direct : assets ready (%d objects fetched)" % n)
EOF

# 4. Assemble classpath + natives + args from the pinned jsons (same
#    placeholder practice as every launcher; unknown placeholder = loud).
#    The Forge json carries only the launchTarget/fml args; the full
#    player/game arg set comes from the vanilla json (measured, no dupes).
WORLD="${AUTOPLAY_WORLD:-matou}"
export AUTOPLAY_WORLD="$WORLD"
# 1201 joins through the official quick-play launch argument (no
# programmatic join surface on modern versions — see the bridge
# tools/autoplay/want.txt): the game itself loads the pre-seeded world
# at boot. Other versions join from the companion mod instead — never
# widen this case silently.
QUICKPLAY_ARGS=""
[ "$SFX" = "1201" ] && QUICKPLAY_ARGS="--quickPlaySingleplayer $WORLD"
export QUICKPLAY_ARGS
# 1201 runs Mojmap-classes/SRG-members like the D3 server: the game jar is
# the installer-provided client-extra (same role as the server-extra the
# D3 unix_args.txt puts on the legacy classpath), NEVER the vanilla
# primary next to it — both carry net.minecraft.obfuscate and JPMS dies
# with a split-package ResolutionException (measured). Other versions keep
# the primary (proven).
USE_CLIENT_EXTRA=""
[ "$SFX" = "1201" ] && USE_CLIENT_EXTRA=1
export USE_CLIENT_EXTRA
OFFLINE_NAME="${OFFLINE_NAME:-MatouDev}"
LAUNCH_LINE="$(python3 - "$VJSON" "$GDIR/versions/$FORGE_ID/$FORGE_ID.json" "$GDIR" "$UP" "$JB" "$OFFLINE_NAME" <<'EOF'
import hashlib, json, os, re, shlex, sys, urllib.request, uuid as U, zipfile
vjson, fjson, gdir, up, jb, player = sys.argv[1:7]
v = json.load(open(vjson))
f = json.load(open(fjson))
def allowed(rules):
    ok = False
    for r in rules or [{"action": "allow"}]:
        a = r["action"] == "allow"
        o = r.get("os", {})
        if "name" in o and o["name"] != "linux":
            continue
        if "arch" in o and o["arch"] != "x64":
            continue
        if "features" in r:
            continue
        ok = a
    return ok
cp, natives, seen = [], [], set()
fetched = [0]
def need(meta, kind):
    # Vanilla libraries the Forge installer assumes the Mojang launcher
    # already provided: fetch missing ones from the pinned json (URL +
    # sha1 carried by the entry — never silent, never upgraded).
    p = os.path.join(gdir, "libraries", meta["path"])
    if os.path.isfile(p):
        return p
    url, sha1 = meta.get("url"), meta.get("sha1")
    assert url, "E_DIRECT_LIB:no url for absent <%s> (installer did not provide it)" % p
    os.makedirs(os.path.dirname(p), exist_ok=True)
    print("note run-direct : fetching %s <%s> (network once)" % (kind, os.path.basename(p)), file=sys.stderr)
    urllib.request.urlretrieve(url, p)
    if sha1:
        import hashlib as H
        got = H.sha1(open(p, "rb").read()).hexdigest()
        assert got == sha1, "E_DIRECT_LIB:sha1 drift <%s> (want %s)" % (p, sha1)
    fetched[0] += 1
    return p
# Forge first: on group:artifact conflicts (e.g. log4j, where Forge pins
# newer than vanilla) the Forge version wins — same as every launcher.
# Naive concatenation puts both on the classpath and dies linking.
seen_native = set()
for lib in f["libraries"] + v["libraries"]:
    if not allowed(lib.get("rules")):
        continue
    segs = lib["name"].split(":")
    key = tuple(segs[:2])
    if len(segs) == 4 and segs[3].startswith("natives"):
        # Separate natives lib (modern era, e.g. 1.20.1 Forge json): the jar
        # carries the .so files LWJGL3 loads from the classpath itself —
        # the accident that carried 1165 green (its Forge natives won the
        # main-lib slot), made deliberate here. Never dedups against the
        # main lib, never feeds the extractor below (basename flattening
        # would shred the linux/x64 hierarchy LWJGL3 requires).
        if key in seen_native:
            continue
        seen_native.add(key)
        dl = lib.get("downloads", {})
        if "artifact" in dl:
            cp.append(need(dl["artifact"], "natives-lib"))
        continue
    if key in seen:
        continue
    seen.add(key)
    dl = lib.get("downloads", {})
    if "artifact" in dl:
        cp.append(need(dl["artifact"], "library"))
    if "classifiers" in dl and "natives-linux" in dl["classifiers"]:
        natives.append(need(dl["classifiers"]["natives-linux"], "natives"))
ndir = os.path.join(up, "natives")
os.makedirs(ndir, exist_ok=True)
import glob as _glob
pj = os.path.join(gdir, "versions", v["id"], v["id"] + ".jar")
if os.environ.get("USE_CLIENT_EXTRA"):
    # Mojmap era: installer-provided client-extra replaces the primary
    # (same trust chain as the server-extra: pinned installer bytes).
    cands = _glob.glob(os.path.join(gdir, "libraries", "net", "minecraft", "client", "*", "client-*-extra.jar"))
    assert len(cands) == 1, "E_DIRECT_LIB:want exactly one client-extra, got %s" % cands
    cp.append(cands[0])
else:
    assert os.path.isfile(pj), "E_DIRECT_LIB:absent primary <%s>" % pj
    cp.append(pj)
for p in natives:
    with zipfile.ZipFile(p) as z:
        for m in z.namelist():
            if m.startswith("META-INF/"):
                continue
            t = os.path.join(ndir, os.path.basename(m))
            if os.path.isfile(t):
                continue
            with z.open(m) as src, open(t, "wb") as dst:
                dst.write(src.read())
def ouuid(name):
    h = hashlib.md5(("OfflinePlayer:" + name).encode()).digest()
    b = bytearray(h)
    b[6] = (b[6] & 0x0F) | 0x30
    b[8] = (b[8] & 0x3F) | 0x80
    return str(U.UUID(bytes=bytes(b))).replace("-", "")
subs = {
    "auth_player_name": player,
    "version_name": f["id"],
    "game_directory": gdir,
    "assets_root": os.path.join(gdir, "assets"),
    "assets_index_name": v["assetIndex"]["id"],
    "auth_uuid": ouuid(player),
    "auth_access_token": "0",
    # Offline placeholders (no Xbox auth here): empty like every offline
    # launcher — online-only features (Realms, skins) are dead anyway.
    "auth_xuid": "",
    "clientid": "",
    "user_type": "mojang",
    "version_type": "release",
    "natives_directory": ndir,
    "launcher_name": "matou-direct",
    "launcher_version": "1",
    "classpath": ":".join(cp),
    "classpath_separator": ":",
    "library_directory": os.path.join(gdir, "libraries"),
}
def sub(s):
    def rep(m):
        k = m.group(1)
        assert k in subs, "E_DIRECT_ARG:unknown placeholder <${%s}>" % k
        return subs[k]
    return re.sub(r"\$\{([^}]+)\}", rep, s)
jvm, game = [], []
# Legacy era (<=1.12: no "arguments" dict, LaunchWrapper main, one
# minecraftArguments string): synthesize the JVM side (heap + natives for
# the old library path) and split the Forge game args. Modern era keeps
# the arguments-dict assembly below. Unknown placeholder = loud either
# way (sub asserts).
legacy = "arguments" not in v
if legacy:
    # LaunchWrapper takes no classpath from the json (the era launcher built
    # -cp itself): pass ours explicitly, Forge-first deduped above, primary
    # jar appended last — same order every launcher used.
    jvm = ["-Djava.library.path=" + subs["natives_directory"],
           "-cp", subs["classpath"]]
    mcargs = f.get("minecraftArguments") or v.get("minecraftArguments")
    assert mcargs, "E_DIRECT_ARG:no minecraftArguments in forge nor vanilla json"
    game = shlex.split(mcargs)
    main = f.get("mainClass") or v.get("mainClass")
    assert main, "E_DIRECT_ARG:no mainClass in forge nor vanilla json"
else:
    main = f["mainClass"]
for a in f.get("arguments", {}).get("jvm", []) + v.get("arguments", {}).get("jvm", []):
    # Forge-first, like game args below: the Forge json extends the vanilla
    # launch (1.20 needs its --add-opens for securejarhandler; 1.16 ran
    # green without its 4 Forge jvm args only because ModLauncher never
    # required them — latent since the 1165-only days).
    if isinstance(a, dict):
        if not allowed(a.get("rules")):
            continue
        jvm.extend(a["value"])
    else:
        jvm.append(a)
for a in f.get("arguments", {}).get("game", []) + v.get("arguments", {}).get("game", []):
    if isinstance(a, dict):
        if not allowed(a.get("rules")):
            continue
        game.extend(a["value"] if isinstance(a["value"], list) else [a["value"]])
    else:
        game.append(a)
qp = os.environ.get("QUICKPLAY_ARGS", "")
if qp:
    game.extend(shlex.split(qp))
print("ok run-direct : launch assembled (%d jars, %s era)" % (len(cp), "legacy" if legacy else "modern"), file=sys.stderr)
print("-Xmx" + os.environ.get("JAVA_XMX", "2G"))
for x in jvm:
    print(sub(x))
print(sub(main))
for x in game:
    print(sub(x))
EOF
)"
[ -n "$LAUNCH_LINE" ] || { echo "FAIL run-direct : empty launch line"; exit 1; }
case "$LAUNCH_LINE" in
  -Xmx*) ;;
  *) echo "FAIL run-direct : launch args polluted (first line is not -Xmx; a stray stdout print leaked into the assembly)"; exit 1;;
esac
printf '%s\n%s\n' "$JB/java" "$LAUNCH_LINE" > "$UP/last-launch.txt"

# 5. Play headless (no launcher, no Qt, no accounts — java + Xvfb only), then
#    judge the save. The exit code is reported but the verdict owns status.
#    CWD is the game dir: the bridge reads config/matoubridge/packs.cfg
#    RELATIVE (like every launcher CWD; a missing file means passive Q1,
#    never an error — launching from anywhere else proves nothing).
unset WAYLAND_DISPLAY
cd "$GDIR" || { echo "FAIL run-direct : cannot cd to game dir <$GDIR>"; exit 1; }
rc=0
printf '%s\n' "$LAUNCH_LINE" | xvfb-run -a xargs -d '\n' "$JB/java" >"$UP/game.log" 2>&1 || rc=$?
echo "note run-direct : game exited ($rc), full log at $UP/game.log"
if [ "${VERIFY:-}" = "0" ]; then
  echo "note run-direct : VERIFY=0, skipping verdict (game rc=$rc)"
  exit "$rc"
fi
echo "note run-direct : replaying verdict on <$WORLD>"
sh "$HUB_TOOLS/verify-client-save.sh" --bridge "$BRIDGE" "$WORLD"
exit $?
