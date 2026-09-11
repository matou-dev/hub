#!/bin/sh
# live-common.sh — shared live-harness steps for the matou-dev org.
# SOURCED by executed harnesses (bridge tools/run-live.sh, hub
# tools/run-client.sh + client-*.sh), never executed, never sourced
# interactively. NOT a gate. Doctrine: hub decisions/LIVE_SHELL_COMMON.md.
#
# Why here: the 4 bridge run-live.sh share 259-377 identical lines (pins,
# normjar/mkjar, preflight, fetch, boot, verdict, anvil loop) and hub
# run-client.sh mirrors the jar helpers — one home, thin version callers.
#
# Contract:
#   - Caller sets no globals: live_init <tag> first (LIVE_TAG prefixes
#     every FAIL/ok line, e.g. b3-live, run-client).
#   - Lib never touches $0 except inside human fix hints (there $0 is the
#     executed wrapper — correct). No `cd`, no sibling discovery: caller
#     owns the cwd (bridge root) and passes absolute dirs.
#   - `exit` on failure: callers are executed harnesses under `set -eu`,
#     same as the code this replaces (never sourced into a live shell).
#   - Env collisions: every helper takes paths/pins as args and uses
#     live_-namespaced locals, never BLD/SERV/UNI (caller-owned).
live_init() {
  LIVE_TAG="$1"
}

# $1 = env var name (e.g. B3_DIR), $2 = dir. Refuses root-owned leftovers
# (docker runs) and non-writable dirs — fail fast, never reuse stale state.
live_preflight_dir() {
  _lvn="$1"; _lvd="$2"
  if [ -e "$_lvd" ]; then
    _lvo=$(find "$_lvd" ! -user "$(id -un)" -print -quit 2>/dev/null || true)
    if [ -n "$_lvo" ]; then
      echo "FAIL $LIVE_TAG : $_lvn=<$_lvd> has non-owned leftovers (e.g. <$_lvo> from a docker run as root)"
      echo "fix: sudo rm -rf <$_lvd/build> <$_lvd/server/world> <$_lvd/server/logs> <$_lvd/server/matou-content> OR $_lvn=/tmp/matou-clean $0"
      exit 1
    fi
    if [ ! -w "$_lvd" ]; then
      echo "FAIL $LIVE_TAG : $_lvn=<$_lvd> not writable (fix ownership or point $_lvn at a user-owned dir)"
      exit 1
    fi
  fi
}

# $1 = file, $2 = url, $3 = sha1, $4 = offline (0|1). Present bytes with a
# drifted sha1 fail loudly (never a silent upgrade); offline + absent fails.
live_fetch() {
  _lf="$1"; _lu="$2"; _ls="$3"; _lo="$4"
  if [ ! -f "$_lf" ]; then
    if [ "$_lo" = "1" ]; then
      echo "FAIL $LIVE_TAG : offline and <$_lf> absent"
      exit 1
    fi
    curl -sL -o "$_lf" "$_lu" \
      || { echo "FAIL $LIVE_TAG : download <$_lu>"; exit 1; }
  fi
  echo "$_ls  $_lf" | sha1sum -c - >/dev/null 2>&1 \
    || { echo "FAIL $LIVE_TAG : sha1 drift on <$_lf> (want $_ls)"; exit 1; }
}

# $1 = server dir, $2 = installer jar, $3 = java bin dir. Idempotent:
# a laid-out universal (or era root jar) skips --installServer.
live_install_server() {
  _lis="$1"; _lii="$2"; _lij="$3"
  _liu=$(find "$_lis" -maxdepth 1 \( -name 'forge-*-universal.jar' -o -name 'forge-1*.jar' \) ! -name '*installer*' 2>/dev/null | head -n 1 || true)
  if [ -z "$_liu" ]; then
    (cd "$_lis" && "$_lij/java" -jar "$_lii" --installServer >/dev/null 2>&1) \
      || { echo "FAIL $LIVE_TAG : --installServer"; exit 1; }
  fi
}

# $1 = SRG map file, $2 = owner/name, $3 = descriptor. A stub the map does
# not know is a loud failure, never a silent default.
live_pin_method() {
  grep -q "^MD: [^ ]* [^ ]* $2 $3\$" "$1" \
    || { echo "FAIL $LIVE_TAG : stub member unpinned <$2 $3>"; exit 1; }
}

# $1 = SRG map file, $2 = owner/name.
live_pin_field() {
  grep -q "^FD: [^ ]* $2\$" "$1" \
    || { echo "FAIL $LIVE_TAG : stub field unpinned <$2>"; exit 1; }
}

# $1 = javap bin, $2 = jar, $3 = class, $4 = grep. Forge classes are never
# obfuscated, so names are final — presence is the pin.
live_pin_uni() {
  "$1/javap" -p -cp "$2" "$3" 2>/dev/null | grep -q "$4" \
    || { echo "FAIL $LIVE_TAG : universal pin unmet <$3 :: $4>"; exit 1; }
}

# $1 = jar, $2 = epoch. Clamps every zip entry timestamp: the JDK jar tool
# stamps META-INF entries with the wall clock (verified by diff), and Reobf
# does the same for its output. python3 is already a hard harness dependency.
live_normjar() {
  python3 - "$1" "$2" <<'EOF'
import sys, zipfile, datetime
path, epoch = sys.argv[1], int(sys.argv[2])
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

# $1 = out jar, $2 = stage dir, $3 = manifest, $4 = jar tool, $5 = epoch.
# File lists stay explicit: jar -C . walks in readdir order (reproducible).
live_mkjar() {
  _lmo="$1"; _lms="$2"; _lmm="$3"; _lmj="$4"; _lme="$5"
  _lmf=$(cd "$_lms" && find . -type f | LC_ALL=C sort)
  # Controlled tree, no spaces in class paths: word-splitting is intended.
  # shellcheck disable=SC2086
  (cd "$_lms" && "$_lmj" cfm "$_lmo" "$_lmm" $_lmf)
  live_normjar "$_lmo" "$_lme"
}

# $1 = jar stage dir, $2 = description. Stages pack.mcmeta at the jar root
# (pre-Reobf: non-class entries pass through untouched, normjar clamps the
# timestamp — deterministic bytes). Empty PACK_FORMAT stages nothing; a
# non-numeric one fails loud (table-owned, never guessed).
live_stage_packmcmeta() {
  case "${PACK_FORMAT:-}" in
    "") return 0;;
    *[!0-9]*) echo "FAIL $LIVE_TAG : PACK_FORMAT=<${PACK_FORMAT:-}> (want digits, table-owned)"; exit 1;;
  esac
  printf '{"pack":{"pack_format":%s,"description":"%s"}}\n' "$PACK_FORMAT" "$2" > "$1/pack.mcmeta"
}

# True when the jar carries Forge mod metadata (mods.toml era or mcmod.info
# era marker). A metadata-less jar in mods/ is inert on the flat slim
# classpath but breaks the isolated FAT boot — callers decide loudly.
live_mod_has_metadata() {
  "$1" tf "$2" 2>/dev/null | grep -q -e "META-INF/mods.toml$" -e "mcmod.info$"
}

# $1 = server dir, $2 = boot secs, $3 = boot log name, $@ = server command.
# The server must run the FULL window (timeout exit 124) — an early exit
# is a loud failure, never a short proof.
live_boot() {
  _lbs="$1"; _lbt="$2"; _lbl="$3"; shift 3
  set +e
  (cd "$_lbs" && timeout "$_lbt" "$@" < /dev/null > "$_lbl" 2>&1)
  _lbc=$?
  set -e
  [ "$_lbc" -eq 124 ] || { echo "FAIL $LIVE_TAG : server exited early (code $_lbc, see $_lbs/$_lbl)"; exit 1; }
  echo "ok $LIVE_TAG : server ran ($_lbt s)"
}

# $1 = refusal grep pattern, $2 = show pattern, $@ = log files. Any runtime
# refusal or linkage error fails loudly; the mod must have loaded.
live_verdict() {
  _lvr="$1"; _lvs="$2"; shift 2
  if grep -a -q "$_lvr" "$@"; then
    echo "FAIL $LIVE_TAG : runtime refusal (see $1)"
    grep -a -m5 "$_lvs" "$@"
    exit 1
  fi
  grep -a -q "matoubridge" "$@" \
    || { echo "FAIL $LIVE_TAG : mod never loaded"; exit 1; }
  echo "ok $LIVE_TAG : bind clean, ticks clean"
}

# $1 = server dir, $2 = build dir. Reads chunks (0..1, -1..1) at y=60..61
# plus y=63..65 into $2/world.txt. Runs in a subshell: the spec split must
# not clobber the caller's positional params. Cwd must be the bridge root
# (tools/live/anvil.py is addressed relatively, as in every caller).
live_anvil_loop() {
  _las="$1"; _lab="$2"
  : > "$_lab/world.txt"
  ( for spec in "r.0.0.mca 0 0" "r.0.0.mca 1 0" "r.0.0.mca 0 1" \
      "r.0.0.mca 1 1" "r.0.-1.mca 0 -1" "r.0.-1.mca 1 -1"; do
    set -- $spec
    for y in 60 61 63 64 65; do
      python3 tools/live/anvil.py "$_las/world/region/$1" "$2" "$3" "$y" \
        | awk -v cx="$2" -v cz="$3" -v y="$y" \
          '{split($1, a, ","); print (cx*16+a[1])" "y" "(cz*16+a[2])" "$2}' \
        >> "$_lab/world.txt"
    done
  done )
}

# $1 = union file, $2 = world file, $3 = packs.cfg, $4 = name=id table
# (frozen vanilla IDs plus dynamic custom IDs the caller resolved from the
# boot log — never hardcoded, never guessed). Numeric-ID eras (1710/1122):
# strictest known shape (both directions + foreign-ID refusal).
live_compare_ids() {
  python3 - "$1" "$2" "$3" "$4" <<'EOF'
import sys
table = {}
for pair in sys.argv[4].split(","):
    name, num = pair.split("=", 1)
    table[name] = num
wire_y, wire_block = None, None
for line in open(sys.argv[3]):
    line = line.strip()
    if line and not line.startswith("#"):
        toks = line.split()
        wire_y, wire_block = int(toks[1]), toks[2]
if wire_y is None:
    print("FAIL live-compare : no wire in packs.cfg")
    sys.exit(1)
if wire_block not in table:
    print("FAIL live-compare : no numeric ID for wire block <%s>" % wire_block)
    sys.exit(1)
u = {}
for line in open(sys.argv[1]):
    cell = line.split()[0]
    parts = cell.split(",")
    if len(parts) == 3 and ":" in parts[2]:
        z, bname = parts[2].split(":", 1)
        pos = (int(parts[0]), int(parts[1]), int(z))
    else:
        x, z = cell.split(",")
        pos, bname = (int(x), wire_y, int(z)), wire_block
    if bname not in table:
        print("FAIL live-compare : no numeric ID for block <%s> (extend the table, never guess)" % bname)
        sys.exit(1)
    u[pos] = table[bname]
rows = [l.split() for l in open(sys.argv[2])]
w = {(int(x), int(y), int(z)): i for x, y, z, i in rows}
if not w:
    print("FAIL live-compare : world empty at y=60..61,63..65 (no tick applied?)")
    sys.exit(1)
if set(w.values()) - set(table.values()):
    print("FAIL live-compare : foreign block ids %s" % sorted(set(w.values()) - set(table.values())))
    sys.exit(1)
bad = {p: (w[p], u.get(p)) for p in w if u.get(p) != w[p]}
if bad:
    print("FAIL live-compare : id mismatch at %s (want pure union ids)" % sorted(bad.items())[:5])
    sys.exit(1)
if set(w) - set(u):
    print("FAIL live-compare : world cells outside pure union %s" % sorted(set(w) - set(u))[:5])
    sys.exit(1)
if set(u) - set(w):
    print("FAIL live-compare : pure cells missing from world (%d)" % len(set(u) - set(w)))
    sys.exit(1)
print("ok live-compare : world == pure union (%d cells, ids %s)" % (len(w), ",".join(sorted(set(w.values())))))
EOF
}

# $1 = union file, $2 = world file, $3 = packs.cfg. Name eras (1165/1201):
# names resolve through packs.cfg itself (wire block plus every
# block.<ref>=<name> alias value) — never hardcoded, never guessed.
live_compare_names() {
  python3 - "$1" "$2" "$3" <<'EOF'
import sys
wire_y, wire_block, allowed = None, None, set()
for line in open(sys.argv[3]):
    line = line.strip()
    if line and not line.startswith("#"):
        toks = line.split()
        wire_y, wire_block = int(toks[1]), toks[2]
        allowed.add(wire_block)
        for tok in toks[3:]:
            if tok.startswith("block.") and "=" in tok:
                allowed.add(tok.split("=", 1)[1])
if wire_y is None:
    print("FAIL live-compare : no wire in packs.cfg")
    sys.exit(1)
u = {}
for line in open(sys.argv[1]):
    cell = line.split()[0]
    parts = cell.split(",")
    if len(parts) == 3 and ":" in parts[2]:
        z, bname = parts[2].split(":", 1)
        pos = (int(parts[0]), int(parts[1]), int(z))
    else:
        x, z = cell.split(",")
        pos, bname = (int(x), wire_y, int(z)), wire_block
    if bname not in allowed:
        print("FAIL live-compare : union block <%s> outside packs.cfg set (extend the wire, never guess)" % bname)
        sys.exit(1)
    u[pos] = bname
rows = [l.split() for l in open(sys.argv[2])]
w = {(int(x), int(y), int(z)): n for x, y, z, n in rows}
if not w:
    print("FAIL live-compare : world empty at y=60..61,63..65 (no tick applied?)")
    sys.exit(1)
if set(w.values()) - allowed:
    print("FAIL live-compare : foreign blocks %s" % sorted(set(w.values()) - allowed))
    sys.exit(1)
bad = {p: (w[p], u.get(p)) for p in w if u.get(p) != w[p]}
if bad:
    print("FAIL live-compare : name mismatch at %s (want pure union names)" % sorted(bad.items())[:5])
    sys.exit(1)
if u.keys() - w.keys():
    print("FAIL live-compare : pure cells missing from world (%d)" % len(u.keys() - w.keys()))
    sys.exit(1)
print("ok live-compare : world == pure union (%d cells, names %s)" % (len(w), sorted(set(w.values()))))
EOF
}
