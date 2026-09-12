#!/bin/sh
# live-derive.sh — shared narrow-map derivation for the matou-dev org.
# SOURCED by executed harnesses (bridge tools/run-live.sh), never executed,
# never sourced interactively. NOT a gate. Doctrine:
# hub decisions/LIVE_SHELL_COMMON.md (addendum 2026-09-11).
#
# Why here: the 1122/1165/1201 run-live.sh derive blocks share one skeleton
# (fetch maps -> parse joined.tsrg -> WANT table -> per-row obf resolve +
# javap static check -> emit MD/FD -> count assert) with three era-bound
# locks that differ line-by-line (anchor shape, snapshot, mojmaps, javap
# field regex, jar split). One function per lock shape, never `if ERA`
# inside (same rule as live-common.sh). WANT rows stay version-measured
# TSV tables owned by the wrappers (bridge tools/live/want.tsv, tab
# separated, order-sensitive — the emit order is the row order); this file
# owns only the mechanics.
#
# Contract (same as live-common.sh):
#   - Caller `cd`s to the bridge root first, sources live-common.sh +
#     this file, calls live_init <tag> before any live_derive_* call.
#   - Lib never touches $0, never `cd`s, never discovers siblings: every
#     input arrives as an arg in live_-namespaced locals. The ok-print tag
#     rides argv (from $LIVE_TAG), never a global read inside python.
#   - `exit` on failure: callers are executed harnesses under `set -eu`.
#   - Original argv positions are preserved per era; the WANT TSV and the
#     tag are appended last. Mechanics are verbatim moves of the era
#     donors (only the WANT source and the ok-print tag changed) —
#     reference-vs-candidate runs against the provisioned caches must diff
#     empty (see the decision addendum for the proof log).

# Era 1.12 (bridge-1122 donor): MCP config only, no snapshot. WANT rows
# (owner, mcp, desc, kind, static) with an optional 6th SRG anchor
# (stable_39 names — several vanilla members share one descriptor, the
# anchor picks the intended one; anchorless fields resolve by javap
# unique-shape). Client-class rows verify against the pinned client jar.
#
# $1 = mcp_config zip, $2 = notch server jar, $3 = javap bin,
# $4 = out narrow map, $5 = pinned vanilla client jar,
# $6 = WANT TSV (owner, mcp, desc, kind, 0|1, anchor-or-empty).
live_derive_mcp_anchor() {
  _lda_cfg="$1"; _lda_srv="$2"; _lda_javap="$3"; _lda_out="$4"
  _lda_cli="$5"; _lda_want="$6"; _lda_tag="$LIVE_TAG"
  python3 - "$_lda_cfg" "$_lda_srv" "$_lda_javap" "$_lda_out" "$_lda_cli" "$_lda_want" "$_lda_tag" <<'EOF'
import re, subprocess, sys, zipfile
mcpcfg, server, javap, outpath, client, wantf, tag = sys.argv[1:8]
tsrg = zipfile.ZipFile(mcpcfg).read("config/joined.tsrg").decode("utf-8")
# WANT rows (owner, mcp, desc, kind, static, [anchor]) arrive as TSV —
# same tuple semantics as the inline donor (anchor None when the 6th
# column is empty). The full vanilla surface of forge/ (constant-pool
# truth); rows with an anchor carry stable_39 names (de.oceanlabs.mcp:
# mcp_stable:39-1.12 on Forge Maven): several vanilla members share one
# descriptor (e.g. setHardness/setResistance, every Material field), so
# the anchor picks the intended one — an anchor missing from the pinned
# bytes fails loud.
WANT = []
for line in open(wantf):
    owner, mcp, desc, kind, static, anchor = line.rstrip("\n").split("\t")
    row = (owner, mcp, desc, kind, static == "1")
    if anchor:
        row = row + (anchor,)
    WANT.append(row)
srg2obf, classes = {}, {}
cur = None
for raw in tsrg.splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        classes.setdefault(cur, []).append(line.split())
    else:
        obf, srg = line.split()
        srg2obf[srg] = obf
        cur = srg

def obf_desc(d):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + srg2obf.get(m.group(1), m.group(1)) + ";", d)

# javap spells primitive field types by name (double, boolean, ...), never
# by descriptor char — the loot tranche pins Entity/posX (D) and
# World/isRemote (Z), so the field-type key maps single-char descriptors
# (object types keep the obf_desc path above). Unobfuscated packages keep
# their dots in javap (java.util.List) while SRG descriptors use slashes,
# so object types normalize to dots — same replace as hub
# tools/run-client.sh (the notch jar spells the obf class with no
# separator at all, so one replace covers both; obf names never contain a
# slash-or-dot). The spawn tranche needs it for World/loadedEntityList.
PRIM = {"Z": "boolean", "B": "byte", "C": "char", "D": "double",
        "F": "float", "I": "int", "J": "long", "S": "short"}

def obf_ftype(d):
    if d in PRIM:
        return PRIM[d]
    return obf_desc(d)[1:-1].replace("/", ".")

def javap_flags(cls, jar):
    # -> {(name, descriptor-or-F:type): is_static} from the notch jar
    # holding the class (server jar, or the pinned client jar for
    # net/minecraft/client/* — chosen per row below, never defaulted).
    out = subprocess.check_output([javap, "-p", "-s", "-cp", jar, cls]).decode()
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
                # Field type class carries ? and & too: the client jar's
                # Minecraft spells Queue<FutureTask<?>> with wildcard
                # bounds (same fix as the hub run-client.sh autoplay
                # derive, C3 proof).
                m2 = re.match(r"(?:(.*)\s)?([\w.$\[\]<>, ?&]+?)\s+([\w$]+);", s)
                assert m2, "E_SRG_DERIVE:unparsed javap line <%s> in <%s>" % (s, cls)
                static = bool(re.search(r"\bstatic\b", m2.group(1) or ""))
                name = m2.group(3)
                res[(name, "F:" + re.sub(r"<.*>", "", m2.group(2)))] = static
    return res

lines = []
for row in WANT:
    owner, mcp, desc, kind, want_static = row[:5]
    anchor = row[5] if len(row) > 5 else None
    # Client classes live in the client jar only — every other owner in
    # the server jar. No default: a future package outside both fails at
    # javap loudly (check_output raises), never maps against the wrong
    # bytes silently. Only net/minecraft/client/* exists there today.
    jar = client if owner.startswith("net/minecraft/client/") else server
    obf_owner = srg2obf[owner]
    members = classes[owner]
    if kind == "method":
        od = obf_desc(desc)
        cands = [(m[0], m[2]) for m in members if len(m) == 3 and m[1] == od]
        if anchor is not None:
            cands = [(n, s) for n, s in cands if s == anchor]
        assert cands, "E_SRG_DERIVE:no tsrg member <%s %s>" % (owner, mcp)
        flags = javap_flags(obf_owner, jar)
        hits = [(n, s) for n, s in cands if flags.get((n, od)) == want_static]
        assert len(hits) == 1, "E_SRG_DERIVE:ambiguous <%s %s> %s" % (owner, mcp, hits)
        lines.append("MD: %s/%s %s %s/%s %s" % (owner, hits[0][1], desc, owner, mcp, desc))
    else:
        if anchor is not None:
            found = [m for m in members if len(m) == 2 and m[1] == anchor]
            assert len(found) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (owner, anchor)
            ftype_obf = obf_ftype(desc)
            flags = javap_flags(obf_owner, jar)
            assert flags.get((found[0][0], "F:" + ftype_obf)) == want_static, \
                "E_SRG_DERIVE:field shape <%s %s>" % (owner, anchor)
            lines.append("FD: %s/%s %s/%s" % (owner, anchor, owner, mcp))
            continue
        ftype_obf = obf_ftype(desc)
        flags = javap_flags(obf_owner, jar)
        flds = [n for (n, d), st in flags.items()
                if d == "F:" + ftype_obf and st == want_static]
        assert len(flds) == 1, "E_SRG_DERIVE:ambiguous field <%s %s> %s" % (owner, mcp, flds)
        hits = [m for m in members if len(m) == 2 and m[0] == flds[0]]
        assert len(hits) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (owner, mcp)
        lines.append("FD: %s/%s %s/%s" % (owner, hits[0][1], owner, mcp))
assert len(lines) == 54, "E_SRG_DERIVE:want 54 lines, got %d" % len(lines)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok %s : narrow SRG derived (%d lines)" % (tag, len(lines)))
EOF
}

# Era 1.16 (bridge-1165 donor): MCP config + snapshot lock. WANT rows
# (owner, srg, mcp, desc, kind, static) — the SRG anchor is always
# present (snapshot SRG name filters first, tsrg + javap still confirm).
# Client-class rows (net/minecraft/client/*, com/mojang/*, Matrix4f)
# verify against the pinned client jar.
#
# $1 = mcp_config zip, $2 = mcp_snapshot zip, $3 = notch server jar,
# $4 = javap bin, $5 = out narrow map, $6 = pinned vanilla client jar,
# $7 = WANT TSV (owner, srg, mcp, desc, kind, 0|1).
live_derive_mcp_snapshot() {
  _lds_cfg="$1"; _lds_snap="$2"; _lds_srv="$3"; _lds_javap="$4"
  _lds_out="$5"; _lds_cli="$6"; _lds_want="$7"; _lds_tag="$LIVE_TAG"
  python3 - "$_lds_cfg" "$_lds_snap" "$_lds_srv" "$_lds_javap" "$_lds_out" "$_lds_cli" "$_lds_want" "$_lds_tag" <<'EOF'
import re, subprocess, sys, zipfile
mcpcfg, snapshot, server, javap, outpath, client, wantf, tag = sys.argv[1:9]
tsrg = zipfile.ZipFile(mcpcfg).read("config/joined.tsrg").decode("utf-8")
# WANT rows (owner_srg, srg_name, mcp_name, desc_srg, kind, static) arrive
# as TSV — the full vanilla surface of forge/ (constant-pool truth).
WANT = []
for line in open(wantf):
    owner, srg, mcp, desc, kind, static = line.rstrip("\n").split("\t")
    WANT.append((owner, srg, mcp, desc, kind, static == "1"))
z = zipfile.ZipFile(snapshot)
mcpnames = {}
for row in z.read("methods.csv").decode("utf-8").splitlines()[1:]:
    mcpnames[row.split(",")[0]] = row.split(",")[1]
for row in z.read("fields.csv").decode("utf-8").splitlines()[1:]:
    mcpnames.setdefault(row.split(",")[0], row.split(",")[1])
for owner, srg, mcp, desc, kind, want_static in WANT:
    assert mcpnames.get(srg) == mcp, \
        "E_SRG_DERIVE:snapshot <%s> is <%s>, want <%s>" % (srg, mcpnames.get(srg), mcp)
print("ok %s : snapshot names confirm %d/%d" % (tag, len(WANT), len(WANT)))
srg2obf, classes = {}, {}
cur = None
for raw in tsrg.splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        classes.setdefault(cur, []).append(line.split())
    else:
        obf, srg = line.split()
        srg2obf[srg] = obf
        cur = srg

def obf_desc(d):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + srg2obf.get(m.group(1), m.group(1)) + ";", d)

# javap spells primitive field types by name (boolean, ...), never by
# descriptor char — the loot tranche pins World/isRemote (Z), so the
# field-type key maps single-char descriptors (object types keep the
# obf_desc path above; same shape as the 1122 loot tranche).
PRIM = {"Z": "boolean", "B": "byte", "C": "char", "D": "double",
        "F": "float", "I": "int", "J": "long", "S": "short"}

def obf_ftype(d):
    if d in PRIM:
        return PRIM[d]
    return obf_desc(d)[1:-1]

def javap_flags(cls, jar):
    # -> {(name, descriptor-or-F:type): is_static} from the notch jar
    # holding the class (server jar, or the pinned client jar for
    # client-only owners — chosen per row below, never defaulted).
    out = subprocess.check_output([javap, "-p", "-s", "-cp", jar, cls]).decode()
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
                # Field type class carries `?` for javap-printed wildcards
                # (e.g. `ceg$d<aqe<?>>` in AbstractBlock$Properties —
                # measured, not assumed: the inner class holds a generic
                # optional field, and the pre-fix class failed loud here).
                m2 = re.match(r"(?:(.*)\s)?([\w.$\[\]<>, ?]+?)\s+([\w$]+);", s)
                assert m2, "E_SRG_DERIVE:unparsed javap line <%s> in <%s>" % (s, cls)
                static = bool(re.search(r"\bstatic\b", m2.group(1) or ""))
                name = m2.group(3)
                res[(name, "F:" + re.sub(r"<.*>", "", m2.group(2)))] = static
    return res

lines = []
for row in WANT:
    owner, srg, mcp, desc, kind, want_static = row[:6]
    # SRG anchor (1122 port lesson): several vanilla members share one
    # descriptor (here four hardnessAndResistance overloads), so javap
    # static-ness alone cannot pick — the snapshot SRG name filters
    # first, tsrg + javap still confirm (an anchor missing from the
    # pinned bytes fails loud).
    anchor = srg
    obf_owner = srg2obf[owner]
    # Client classes live in the client jar only (plus Matrix4f, whose
    # write() the server bytes lack — measured) — every other owner in
    # the server jar. No default: a future package outside both fails at
    # javap loudly (check_output raises), never maps against the wrong
    # bytes silently.
    jar = client if (owner.startswith("net/minecraft/client/")
            or owner.startswith("com/mojang/")
            or owner == "net/minecraft/util/math/vector/Matrix4f") else server
    members = classes[owner]
    flags = javap_flags(obf_owner, jar)
    if kind == "method":
        od = obf_desc(desc)
        cands = [(m[0], m[2]) for m in members if len(m) == 3 and m[1] == od]
        assert cands, "E_SRG_DERIVE:no tsrg member <%s %s>" % (owner, mcp)
        cands = [(n, s) for n, s in cands if s == anchor]
        assert cands, "E_SRG_DERIVE:no tsrg member <%s %s> (anchor %s absent)" % (owner, mcp, anchor)
        hits = [(n, s) for n, s in cands if flags.get((n, od)) == want_static]
        assert len(hits) == 1, "E_SRG_DERIVE:ambiguous <%s %s> %s" % (owner, mcp, hits)
        assert hits[0][1] == srg, \
            "E_SRG_DERIVE:srg mismatch <%s %s> got %s want %s" % (owner, mcp, hits[0][1], srg)
        lines.append("MD: %s/%s %s %s/%s %s" % (owner, hits[0][1], desc, owner, mcp, desc))
    else:
        tm = [m for m in members if len(m) == 2 and m[1] == srg]
        assert len(tm) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (owner, srg)
        ftype_obf = obf_ftype(desc)
        assert flags.get((tm[0][0], "F:" + ftype_obf)) == want_static, \
            "E_SRG_DERIVE:javap mismatch field <%s %s>" % (owner, srg)
        lines.append("FD: %s/%s %s/%s" % (owner, tm[0][1], owner, mcp))
assert len(lines) == 59, "E_SRG_DERIVE:want 59 lines, got %d" % len(lines)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok %s : narrow SRG derived (%d lines)" % (tag, len(lines)))
EOF
}

# Era 1.20 (bridge-1201 donor): Mojang server/client mappings + joined.tsrg
# + dual-javap triple lock. WANT rows (owner, mcp, desc-or-ftype, static)
# grouped: METHODS + FIELDS (server mojmap hop + inner-server javap leg),
# METHODS_CLIENT + FIELDS_CLIENT (client.txt hop + vanilla-client javap
# leg), SAM_CLIENT (client mojmap + tsrg hops only — client classes never
# ship in the provisioned server jars, so no javap can disambiguate; the
# two exact-one asserts plus the live client run own the row).
#
# $1 = mcp_config zip, $2 = server-mappings.txt, $3 = inner server jar,
# $4 = javap bin, $5 = out narrow map, $6 = client-mappings.txt,
# $7 = vanilla client jar, $8 = WANT TSV
# (group, owner, mcp, desc-or-ftype, 0|1).
live_derive_mojmaps() {
  _ldm_cfg="$1"; _ldm_moj="$2"; _ldm_srv="$3"; _ldm_javap="$4"
  _ldm_out="$5"; _ldm_cmap="$6"; _ldm_cli="$7"; _ldm_want="$8"; _ldm_tag="$LIVE_TAG"
  python3 - "$_ldm_cfg" "$_ldm_moj" "$_ldm_srv" "$_ldm_javap" "$_ldm_out" "$_ldm_cmap" "$_ldm_cli" "$_ldm_want" "$_ldm_tag" <<'EOF'
import re, subprocess, sys, zipfile
mcpcfg, mojmaps, server, javap, outpath, climaps, client, wantf, tag = sys.argv[1:10]
tsrg = zipfile.ZipFile(mcpcfg).read("config/joined.tsrg").decode("utf-8")
# WANT rows arrive as TSV (group, owner, mcp, desc-or-ftype, static) —
# same tuple semantics as the inline donor, grouped per triple-lock leg.
GROUPS = {"METHODS": [], "FIELDS": [], "METHODS_CLIENT": [],
          "FIELDS_CLIENT": [], "SAM_CLIENT": []}
for line in open(wantf):
    group, owner, mcp, desc, static = line.rstrip("\n").split("\t")
    assert group in GROUPS, "E_SRG_DERIVE:unknown WANT group <%s>" % group
    GROUPS[group].append((owner, mcp, desc, static == "1"))
WANT_METHODS = GROUPS["METHODS"]
WANT_FIELDS = GROUPS["FIELDS"]
WANT_METHODS_CLIENT = GROUPS["METHODS_CLIENT"]
WANT_FIELDS_CLIENT = GROUPS["FIELDS_CLIENT"]
WANT_SAM_CLIENT = GROUPS["SAM_CLIENT"]
# moj class (dots) -> obf class; moj class -> [(kind, rettype, name, args, obf)]
moj2obf, members = {}, {}
cur = None
for raw in open(mojmaps):
    if not raw.strip() or raw.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        m = re.match(r"^\s+(?:\d+:\d+:)?(\S+) ([\w$<>]+)(\(.*\))? -> ([\w$<>]+)$", raw.rstrip())
        assert m, "E_SRG_DERIVE:unparsed mappings line <%s>" % raw.rstrip()
        rettype, name, args, obf = m.groups()
        kind = "method" if args is not None else "field"
        members.setdefault(cur, []).append((kind, rettype, name, args or "", obf))
    else:
        if "package-info -> " in raw:
            continue  # ProGuard package marker, never a WANT owner
        m = re.match(r"^([\w.$]+) -> ([\w$.]+):$", raw.rstrip())
        assert m, "E_SRG_DERIVE:unparsed mappings class <%s>" % raw.rstrip()
        cur = m.group(1)
        moj2obf[cur] = m.group(2)
        members.setdefault(cur, [])
# Client map (same ProGuard shape): client-only classes live here alone
# (server.txt never names them). Separate tables — client.txt also
# covers shared classes, and merging would double members the
# exactly-one asserts must see once.
cmoj2obf, cmembers = {}, {}
cur = None
for raw in open(climaps):
    if not raw.strip() or raw.startswith("#"):
        continue
    if raw[0] in (" ", "\t"):
        m = re.match(r"^\s+(?:\d+:\d+:)?(\S+) ([\w$<>]+)(\(.*\))? -> ([\w$<>]+)$", raw.rstrip())
        assert m, "E_SRG_DERIVE:unparsed client mappings line <%s>" % raw.rstrip()
        rettype, name, args, obf = m.groups()
        kind = "method" if args is not None else "field"
        cmembers.setdefault(cur, []).append((kind, rettype, name, args or "", obf))
    else:
        if "package-info -> " in raw:
            continue  # ProGuard package marker, never a WANT owner
        m = re.match(r"^([\w.$]+) -> ([\w$.]+):$", raw.rstrip())
        assert m, "E_SRG_DERIVE:unparsed client mappings class <%s>" % raw.rstrip()
        cur = m.group(1)
        cmoj2obf[cur] = m.group(2)
        cmembers.setdefault(cur, [])

def to_internal(moj_dots):
    return moj_dots.replace(".", "/")

def obf_desc(moj_desc):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + to_internal(moj2obf.get(m.group(1).replace("/", "."), m.group(1))) + ";",
                  moj_desc)

def cobf_desc(moj_desc):
    # Client-row resolver: client.txt first (client-only classes live
    # there alone), server.txt fallback (shared classes map identically
    # in both Mojang files — same obf namespace, never two answers).
    def obf(moj_slashes):
        moj_dots = moj_slashes.replace("/", ".")
        if moj_dots in cmoj2obf:
            return to_internal(cmoj2obf[moj_dots])
        return to_internal(moj2obf.get(moj_dots, moj_slashes))
    return re.sub(r"L([^;]+);", lambda m: "L" + obf(m.group(1)) + ";",
                  moj_desc)

def srg_desc(obf_d, obf2srg):
    return re.sub(r"L([^;]+);",
                  lambda m: "L" + obf2srg.get(m.group(1), m.group(1)) + ";",
                  obf_d)

# TSRG v2: class lines `obf srg [id]`; member lines (one tab) `obf [desc] srg
# [id]` — methods carry a descriptor, fields do not; a `static` line (two
# tabs) follows the member it describes, param lines are ignored.
obf2srg, classes = {}, {}
cur = None
for raw in tsrg.splitlines():
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
            classes[cur].append({"obf": parts[0], "desc": parts[1],
                                 "srg": parts[2], "static": False})
        else:
            classes[cur].append({"obf": parts[0], "desc": None,
                                 "srg": parts[1], "static": False})
    else:
        obf, srg = raw.split()[:2]
        obf2srg[obf] = srg
        cur = obf
        classes.setdefault(cur, [])

def javap_flags(cls, jar):
    # -> {(name, descriptor-or-F:type): is_static} from the obf jar
    # holding the class (inner server jar, or the pinned vanilla client
    # jar for client-only owners — chosen per row below, never defaulted).
    out = subprocess.check_output([javap, "-p", "-s", "-cp", jar, cls]).decode()
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
                # Field type class carries `?` for javap-printed wildcards
                # (a generic Function field in BlockBehaviour$Properties —
                # measured, not assumed: the pre-fix class failed loud
                # here, same family as the 1165 wildcard finding).
                m2 = re.match(r"(?:(.*)\s)?([\w.$\[\]<>, ?]+?)\s+([\w$]+);", s)
                assert m2, "E_SRG_DERIVE:unparsed javap line <%s> in <%s>" % (s, cls)
                static = bool(re.search(r"\bstatic\b", m2.group(1) or ""))
                name = m2.group(3)
                res[(name, "F:" + re.sub(r"<.*>", "", m2.group(2)))] = static
    return res

PRIM = {"B": "byte", "C": "char", "D": "double", "F": "float",
          "I": "int", "J": "long", "S": "short", "Z": "boolean", "V": "void"}

def desc_args(desc):
    # Descriptor args "(L...;I)Z" -> moj-dot list ["net.minecraft...", "int"].
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
    assert a.startswith("(") and a.endswith(")"), "E_SRG_DERIVE:bad args <%s>" % a
    return [x for x in a[1:-1].split(",") if x]

MOJ_PRIM = {"B": "byte", "C": "char", "D": "double", "F": "float",
            "I": "int", "J": "long", "S": "short", "Z": "boolean"}

def field_type_match(rettype, ftype):
    # Mappings field type vs the WANT descriptor: object types compare
    # slash-normalized, primitives by Java name (the renderer tranche's
    # xo/yo/zo + yRotO/xRotO are the first primitive rows — the old
    # object-only comparison matched nothing for them). The strip is
    # [1:-1] only: a blanket .replace("L","") would eat inner capitals
    # (caught by ClientLevel here — no prior type contained one, so the
    # old shape never fired).
    if len(ftype) == 1:
        return rettype == MOJ_PRIM[ftype]
    return rettype.replace(".", "/") == ftype[1:-1]

def javap_ftype(ftype, obf_fn):
    # javap prints "F:double", never "F:D" — same primitive split (the
    # object leg maps through the given obf descriptor function: server
    # rows through obf_desc, client rows through cobf_desc).
    if len(ftype) == 1:
        return MOJ_PRIM[ftype]
    return obf_fn(ftype)[1:-1]

lines = []
for owner, mcp, desc, want_static in WANT_METHODS:
    moj_cls = owner.replace("/", ".")
    obf_owner = moj2obf[moj_cls]
    want_args = desc_args(desc)
    cands = [(k, r, n, a, o) for (k, r, n, a, o) in members[moj_cls]
             if k == "method" and n == mcp and norm_args(a) == want_args]
    assert len(cands) == 1, "E_SRG_DERIVE:mojmap member <%s %s%s> %s" % (owner, mcp, desc, cands)
    obf_name = cands[0][4]
    od = obf_desc(desc)
    tm = [m for m in classes[obf_owner]
          if m["desc"] == od and m["obf"] == obf_name]
    assert len(tm) == 1, "E_SRG_DERIVE:no tsrg member <%s %s %s>" % (obf_owner, obf_name, od)
    flags = javap_flags(obf_owner, server)
    assert flags.get((obf_name, od)) == want_static, \
        "E_SRG_DERIVE:javap mismatch <%s %s> %s" % (obf_owner, obf_name, flags.get((obf_name, od)))
    sd = srg_desc(od, obf2srg)
    lines.append("MD: %s/%s %s %s/%s %s" % (obf2srg[obf_owner], tm[0]["srg"], sd, owner, mcp, desc))
for owner, mcp, ftype, want_static in WANT_FIELDS:
    moj_cls = owner.replace("/", ".")
    obf_owner = moj2obf[moj_cls]
    cands = [(k, r, n, a, o) for (k, r, n, a, o) in members[moj_cls]
             if k == "field" and n == mcp and field_type_match(r, ftype)]
    assert len(cands) == 1, "E_SRG_DERIVE:mojmap field <%s %s> %s" % (owner, mcp, cands)
    obf_name = cands[0][4]
    tm = [m for m in classes[obf_owner]
          if m["desc"] is None and m["obf"] == obf_name]
    assert len(tm) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (obf_owner, obf_name)
    flags = javap_flags(obf_owner, server)
    ftype_obf = javap_ftype(ftype, obf_desc)
    assert flags.get((obf_name, "F:" + ftype_obf)) == want_static, \
        "E_SRG_DERIVE:javap mismatch field <%s %s>" % (obf_owner, obf_name)
    lines.append("FD: %s/%s %s/%s" % (obf2srg[obf_owner], tm[0]["srg"], owner, mcp))
for owner, mcp, desc, want_static in WANT_METHODS_CLIENT:
    moj_cls = owner.replace("/", ".")
    assert moj_cls in cmoj2obf, "E_SRG_DERIVE:no client class <%s>" % owner
    obf_owner = cmoj2obf[moj_cls]
    want_args = desc_args(desc)
    cands = [(k, r, n, a, o) for (k, r, n, a, o) in cmembers[moj_cls]
             if k == "method" and n == mcp and norm_args(a) == want_args]
    assert len(cands) == 1, "E_SRG_DERIVE:client mojmap member <%s %s%s> %s" % (owner, mcp, desc, cands)
    obf_name = cands[0][4]
    od = cobf_desc(desc)
    tm = [m for m in classes[obf_owner]
          if m["desc"] == od and m["obf"] == obf_name]
    assert len(tm) == 1, "E_SRG_DERIVE:no tsrg member <%s %s %s>" % (obf_owner, obf_name, od)
    flags = javap_flags(obf_owner, client)
    assert flags.get((obf_name, od)) == want_static, \
        "E_SRG_DERIVE:client javap mismatch <%s %s> %s" % (obf_owner, obf_name, flags.get((obf_name, od)))
    sd = srg_desc(od, obf2srg)
    lines.append("MD: %s/%s %s %s/%s %s" % (obf2srg[obf_owner], tm[0]["srg"], sd, owner, mcp, desc))
for owner, mcp, ftype, want_static in WANT_FIELDS_CLIENT:
    moj_cls = owner.replace("/", ".")
    assert moj_cls in cmoj2obf, "E_SRG_DERIVE:no client class <%s>" % owner
    obf_owner = cmoj2obf[moj_cls]
    cands = [(k, r, n, a, o) for (k, r, n, a, o) in cmembers[moj_cls]
             if k == "field" and n == mcp and field_type_match(r, ftype)]
    assert len(cands) == 1, "E_SRG_DERIVE:client mojmap field <%s %s> %s" % (owner, mcp, cands)
    obf_name = cands[0][4]
    tm = [m for m in classes[obf_owner]
          if m["desc"] is None and m["obf"] == obf_name]
    assert len(tm) == 1, "E_SRG_DERIVE:no tsrg field <%s %s>" % (obf_owner, obf_name)
    flags = javap_flags(obf_owner, client)
    ftype_obf = javap_ftype(ftype, cobf_desc)
    assert flags.get((obf_name, "F:" + ftype_obf)) == want_static, \
        "E_SRG_DERIVE:client javap mismatch field <%s %s>" % (obf_owner, obf_name)
    lines.append("FD: %s/%s %s/%s" % (obf2srg[obf_owner], tm[0]["srg"], owner, mcp))
for owner, mcp, desc, want_static in WANT_SAM_CLIENT:
    moj_cls = owner.replace("/", ".")
    assert moj_cls in cmoj2obf, "E_SRG_DERIVE:no client class <%s>" % owner
    obf_owner = cmoj2obf[moj_cls]
    want_args = desc_args(desc)
    cands = [(k, r, n, a, o) for (k, r, n, a, o) in cmembers[moj_cls]
             if k == "method" and n == mcp and norm_args(a) == want_args]
    assert len(cands) == 1, "E_SRG_DERIVE:client mojmap member <%s %s%s> %s" % (owner, mcp, desc, cands)
    obf_name = cands[0][4]
    od = cobf_desc(desc)
    tm = [m for m in classes[obf_owner]
          if m["desc"] == od and m["obf"] == obf_name]
    assert len(tm) == 1, "E_SRG_DERIVE:no tsrg member <%s %s %s>" % (obf_owner, obf_name, od)
    # No javap leg here (client classes never ship in the provisioned
    # server jars — see the WANT_SAM_CLIENT note): the two exact-one
    # asserts above plus the live client run own this row. want_static
    # is documentary (an interface SAM is never static) and unchecked.
    sd = srg_desc(od, obf2srg)
    lines.append("MD: %s/%s %s %s/%s %s" % (obf2srg[obf_owner], tm[0]["srg"], sd, owner, mcp, desc))
assert len(lines) == 59, "E_SRG_DERIVE:want 59 lines, got %d" % len(lines)
open(outpath, "w").write("\n".join(lines) + "\n")
print("ok %s : narrow SRG derived (%d lines)" % (tag, len(lines)))
EOF
}
