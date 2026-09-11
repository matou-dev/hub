#!/bin/sh
# client-autoplay.sh — autoplay companion derive + build (DEV ONLY).
# SOURCED by hub tools/run-client.sh at the §1b point, never executed.
# Moved verbatim from run-client.sh (ceiling split, same commit — every
# FAIL/ok line keeps its `run-client` tag). Expects, all set before the
# §1b point: AUTOPLAY BRIDGE CLIENT_DIR LIVE_DIR SRG_MCP SRG_DEFAULT JB
# JFLAGS BLD MOD_CP REOBF_CP MODS_STYLE VERSION + helpers
# stage_packmcmeta/mkjar/normjar (live-common.sh adapters in run-client.sh).
# Sets: HAVE_AUTOPLAY (=1 when built), SRG_AUTO, UP.
# 1b. Autoplay companion (DEV ONLY, AUTOPLAY=1): derive the companion
#     narrow map (MCP era: pinned vanilla CLIENT jar + joined.tsrg, or the
#     searge-era srg-mcp filter when the bridge ships tools/autoplay/
#     srg-mcp.txt; Mojmap era: official client mappings + joined.tsrg v2 —
#     same javap/tsrg practice as the live derive, but DEV-scoped: the live
#     srg-narrow.srg is never touched), pin every WANT line plus the
#     bridge universal-pin.txt Forge surface, then build + reobf the
#     companion. Bridge owns tools/autoplay/{want.txt,client-pin.txt,
#     universal-pin.txt,srg-mcp.txt,src,stub,autoplay-mods.toml,preseed.py};
#     hub owns this machinery. Absent want.txt = bridge without autoplay: loud.
HAVE_AUTOPLAY=0
if [ "${AUTOPLAY:-}" = "1" ]; then
  [ -f tools/autoplay/want.txt ] \
    || { echo "FAIL run-client : no autoplay WANT (tools/autoplay/want.txt absent in $BRIDGE)"; exit 1; }
  if [ -f tools/autoplay/srg-mcp.txt ]; then
    # Searge mode (e.g. 1710): no vanilla client fetch (javap runs against
    # the universal — the runtime is searge-named, vanilla is true-obf).
    [ -f tools/autoplay/universal-pin.txt ] \
      || { echo "FAIL run-client : tools/autoplay/universal-pin.txt absent in $BRIDGE"; exit 1; }
  else
    [ -f tools/autoplay/client-pin.txt ] && [ -f tools/autoplay/universal-pin.txt ] \
      || { echo "FAIL run-client : tools/autoplay/{client-pin,universal-pin}.txt absent in $BRIDGE"; exit 1; }
  fi
  UP="$CLIENT_DIR/upstream"
  mkdir -p "$UP"
  if [ ! -f tools/autoplay/srg-mcp.txt ]; then
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
  else
    echo "note run-client : searge mode, no vanilla client fetch (javap runs against the universal)"
  fi
  if [ ! -f tools/autoplay/srg-mcp.txt ]; then
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
  else
    echo "note run-client : searge mode, no mcp_config (map is the pinned srg-mcp.srg)"
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
  # Searge era (srg-mcp.txt present, e.g. 1710): the runtime is itself
  # searge-named, so the narrow map filters the pinned srg-mcp.srg — no
  # mcp_config, no snapshot CSVs, no vanilla javap (true-obf names). Each
  # M line must match exactly one MD line (searge + MCP + both descs);
  # static-ness rides the 1122-pinned triple (same searge + desc proven
  # there by javap + snapshot). Each F line (vanilla field the companion
  # reads, e.g. a dimension filter) must match exactly one FD line
  # (searge + MCP). Matched lines pass through verbatim: Reobf
  # already consumes this shape live (bridge run-live.sh reobfuscates
  # against $SRG_MCP directly, methods and fields alike).
  if [ -f tools/autoplay/srg-mcp.txt ]; then
    WANT_SHA1="$(sed -n 's/^SHA1=//p' tools/autoplay/srg-mcp.txt)"
    BRIDGE_SRG_PIN="$(sed -n 's/^SRG_MCP_SHA1="//p' tools/run-live.sh | cut -d'"' -f1)"
    [ -n "$WANT_SHA1" ] && [ "$WANT_SHA1" = "$BRIDGE_SRG_PIN" ] \
      || { echo "FAIL run-client : srg-mcp.txt SHA1 != bridge SRG_MCP_SHA1 (bridge owns it: <$BRIDGE_SRG_PIN>)"; exit 1; }
    SRG_MCP_FILE="${SRG_MCP:-$SRG_DEFAULT}"
    [ -f "$SRG_MCP_FILE" ] \
      || { echo "FAIL run-client : SRG_MCP=<$SRG_MCP_FILE> missing (set SRG_MCP or run a ForgeGradle 1614 setup once)"; exit 1; }
    echo "$WANT_SHA1  $SRG_MCP_FILE" | sha1sum -c - >/dev/null 2>&1 \
      || { echo "FAIL run-client : searge map sha1 drift (want $WANT_SHA1, never silent upgrade)"; exit 1; }
    echo "ok run-client : searge map pinned ($WANT_SHA1)"
    python3 - "$SRG_MCP_FILE" "tools/autoplay/want.txt" "$SRG_AUTO" <<'EOF'
import sys
srg, wantf, outpath = sys.argv[1:4]
md = [l.rstrip("\n") for l in open(srg) if l.startswith("MD: ")]
fd = [l.rstrip("\n") for l in open(srg) if l.startswith("FD: ")]
lines = []
for raw in open(wantf):
    raw = raw.strip()
    if not raw or raw.startswith("#"):
        continue
    toks = raw.split()
    if toks[0] == "M":
        assert len(toks) == 6, "E_AUTO_DERIVE:bad M line <%s> (want <M owner mcp srg desc static>)" % raw
        kind, owner, mcp, srg_want, desc, want_static = toks
        want = "MD: %s/%s %s %s/%s %s" % (owner, srg_want, desc, owner, mcp, desc)
        hits = [l for l in md if l == want]
        assert len(hits) == 1, "E_AUTO_DERIVE:searge member <%s %s %s> matches %d" % (owner, mcp, srg_want, len(hits))
        lines.append(hits[0])
    elif toks[0] == "F":
        assert len(toks) == 4, "E_AUTO_DERIVE:bad F line <%s> (want <F owner mcp srg>)" % raw
        kind, owner, mcp, srg_want = toks
        want = "FD: %s/%s %s/%s" % (owner, srg_want, owner, mcp)
        hits = [l for l in fd if l == want]
        assert len(hits) == 1, "E_AUTO_DERIVE:searge field <%s %s %s> matches %d" % (owner, mcp, srg_want, len(hits))
        lines.append(hits[0])
    else:
        raise SystemExit("E_AUTO_DERIVE:only M|F lines supported (got <%s>)" % raw)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok autoplay-derive : narrow SRG derived (%d lines, srg-mcp)" % len(lines))
EOF
  elif [ -f tools/autoplay/client-mappings-pin.txt ]; then
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
# javap spells primitive field types by name (double, boolean, ...), never
# by descriptor char — same PRIM table as the live derive in each bridge
# run-live.sh. Object types keep the obf_desc path, normalized to the
# dots javap prints (the notch client jar spells java.util.List with
# dots, the obf class with no separator at all — one replace covers
# both, obf names never contain a slash-or-dot).
PRIM = {"Z": "boolean", "B": "byte", "C": "char", "D": "double",
        "F": "float", "I": "int", "J": "long", "S": "short"}
def obf_ftype(d):
    if d in PRIM:
        return PRIM[d]
    return obf_desc(d)[1:-1].replace("/", ".")
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
    elif kind == "F":
        # Field rows (first consumer: the 1122 loot companion, which polls
        # entity positions and the player/entity lists): SRG-anchored like
        # the live field derive — descriptor alone cannot pick the List
        # fields — then javap shape-checked (type + static) against the
        # pinned client jar, snapshot-locked where snapshots exist.
        found = [mm for mm in members if len(mm) == 2 and mm[1] == srg_want]
        assert len(found) == 1, "E_AUTO_DERIVE:no tsrg field <%s %s>" % (owner, srg_want)
        ftype = obf_ftype(desc)
        flags = javap_flags(obf_owner)
        assert flags.get((found[0][0], "F:" + ftype)) == want_static, \
            "E_AUTO_DERIVE:field shape <%s %s>" % (owner, srg_want)
        if snap_f:
            assert snap_f.get(srg_want) == mcp, "E_AUTO_DERIVE:snapshot lock <%s> is <%s>, want <%s>" % (srg_want, snap_f.get(srg_want), mcp)
        lines.append("FD: %s/%s %s/%s" % (owner, srg_want, owner, mcp))
    else:
        raise SystemExit("E_AUTO_DERIVE:only M/F lines supported (got <%s>)" % raw)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok autoplay-derive : narrow SRG derived (%d lines)" % len(lines))
EOF
  fi
  [ "$(grep -c . "$SRG_AUTO")" = "$(grep -cv -e '^#' -e '^$' tools/autoplay/want.txt)" ] \
    || { echo "FAIL run-client : autoplay narrow map drift (want $(grep -cv -e '^#' -e '^$' tools/autoplay/want.txt) lines)"; exit 1; }
  echo "ok run-client : companion narrow map pinned ($SRG_AUTO)"
  mkdir -p "$BLD/auto" "$BLD/autoplaymod/META-INF"
  # $BLD/forge on the classpath (compile only, never staged): the 1710
  # companion matches the registered beast class (hub decisions/SPAWN.md,
  # custom entity tranche — vanilla pigs are a different species now).
  # Staging still copies $BLD/auto/fr only, so no forge class ships in
  # the companion jar (the stub-leak check below keeps proving it).
  # tools/autoplay/stub is optional per bridge (1122 merged its vanilla
  # shapes into tools/live/stub — one Minecraft class only, duplicate
  # stubs never compile): absent dir is skipped, a build with no source
  # left still fails loudly at javac. Controlled tree, no spaces in
  # paths: word-splitting of $AUTO_SRC is intended.
  AUTO_SRC="tools/autoplay/src tools/live/stub"
  [ -d tools/autoplay/stub ] && AUTO_SRC="$AUTO_SRC tools/autoplay/stub"
  "$JB/javac" $JFLAGS -nowarn -cp "$BLD/spi:$BLD/forge" -d "$BLD/auto" $(find $AUTO_SRC -name '*.java')
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
  stage_packmcmeta "$BLD/autoplaystage" "MatouAutoplay DEV (hub run-client.sh, not release)"
  mkjar "$BLD/jars/matouautoplay.jar" "$BLD/autoplaystage"
  "$JB/javac" -nowarn -cp "$REOBF_CP" -d "$BLD" tools/live/Reobf.java
  "$JB/java" -cp "$BLD:$REOBF_CP" Reobf "$SRG_AUTO" "$BLD/jars/matouautoplay.jar" "$BLD/jars/matouautoplay-reobf.jar"
  normjar "$BLD/jars/matouautoplay-reobf.jar"
  echo "ok run-client : autoplay companion built (DEV-only, never in dist/)"
  HAVE_AUTOPLAY=1
fi
