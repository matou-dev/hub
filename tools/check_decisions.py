#!/usr/bin/env python3
"""Gate decisions-parity: every decisions/*.md carries closed front-matter
(type/status/roadmap) and is listed once in the GENERATED block of
decisions/DECISIONS_INDEX_AND_STATUS.md (SSOT = front-matter). Every
decisions/*.md token across *.md must name a file on disk (dead links fail
loudly). Plain run compares (any drift fails loudly); --fix regenerates the
block. No Minecraft imports.
"""
import os
import re
import sys

INDEX = os.path.join("decisions", "DECISIONS_INDEX_AND_STATUS.md")
BEGIN = ("<!-- GENERATED:decisions front-matter -> index | do not hand-edit "
         "| tools/check.sh --fix -->")
END = "<!-- END GENERATED:decisions -->"
TYPES = ("ruling", "spec", "direction", "note")
STATUSES = ("done", "active", "direction", "parked", "superseded")
FM = re.compile(
    r"\A---\ntype: (\S+)\nstatus: (\S+)\nroadmap: (\S+)\n---\n")
LINK = re.compile(r"decisions/([A-Za-z0-9_.\-]+\.md)")


def fail(msg):
    print("FAIL decisions-parity : %s" % msg)
    return 1


def read_front_matter(path):
    with open(path, encoding="utf-8") as fh:
        head = fh.read(512)
    m = FM.match(head)
    if not m:
        return None, "bad front-matter in <%s> (want ---/type/status/roadmap/--- first)" % path
    typ, status, roadmap = m.groups()
    if typ not in TYPES:
        return None, "bad type <%s> in <%s> (want one of %s)" % (typ, path, "|".join(TYPES))
    if status not in STATUSES:
        return None, "bad status <%s> in <%s> (want one of %s)" % (status, path, "|".join(STATUSES))
    if not roadmap:
        return None, "empty roadmap in <%s> (want phase id or -)" % path
    return (typ, status, roadmap), ""


def want_block(entries):
    lines = []
    for typ in TYPES:
        rows = sorted(f for f, (t, _s, _r) in entries.items() if t == typ)
        if not rows:
            continue
        lines.append("### %s" % typ)
        for f in rows:
            _t, s, r = entries[f]
            lines.append("- %s : %s (roadmap %s)" % (f, s, r))
    return lines


def main(fix):
    if not os.path.isdir("decisions"):
        return fail("decisions/ absent")
    entries = {}
    for f in sorted(os.listdir("decisions")):
        if not f.endswith(".md"):
            continue
        fm, err = read_front_matter(os.path.join("decisions", f))
        if fm is None:
            return fail(err)
        entries[f] = fm
    if not entries:
        return fail("no decisions/*.md files")
    # Dead-link scan over tracked *.md (untracked files cannot lie to the next agent).
    import subprocess
    tracked = subprocess.run(
        ["git", "ls-files", "*.md"], capture_output=True, text=True)
    md_files = tracked.stdout.split() if tracked.returncode == 0 else []
    if not md_files:
        for root, _dirs, files in os.walk("."):
            if "/.git" in root:
                continue
            for f in files:
                if f.endswith(".md"):
                    md_files.append(os.path.join(root, f))
    for path in md_files:
        with open(path, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                for m in LINK.finditer(line):
                    target = os.path.join("decisions", m.group(1))
                    if not os.path.isfile(target):
                        return fail("dead link %s:%d -> %s" % (path, n, target))
    # Index parity.
    if not os.path.isfile(INDEX):
        return fail("index <%s> absent" % INDEX)
    with open(INDEX, encoding="utf-8") as fh:
        text = fh.read()
    if BEGIN not in text or END not in text:
        return fail("GENERATED block markers absent in <%s>" % INDEX)
    want = want_block(entries)
    pre, rest = text.split(BEGIN, 1)
    mid, post = rest.split(END, 1)
    got = [l for l in mid.strip("\n").split("\n")] if mid.strip() else []
    if got == want:
        print("ok decisions-parity : %d files in sync" % len(entries))
        return 0
    if not fix:
        print("FAIL decisions-parity : index drifted "
              "(run tools/check.sh --fix)")
        for line in want:
            if line not in got:
                print("  want: %s" % line)
        for line in got:
            if line not in want:
                print("  got:  %s" % line)
        return 1
    with open(INDEX, "w", encoding="utf-8") as fh:
        fh.write(pre + BEGIN + "\n" + "\n".join(want) + "\n" + END + post)
    print("ok decisions-parity : regenerated %d files" % len(entries))
    return 0


if __name__ == "__main__":
    sys.exit(main(len(sys.argv) > 1 and sys.argv[1] == "--fix"))
