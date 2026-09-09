#!/usr/bin/env python3
"""Gate state-parity: phase statuses are stated once (ROADMAP.md table, SSOT)
and derived once (STATE.md GENERATED block). Plain run compares (any drift
fails loudly); --fix regenerates the block. No Minecraft imports.
"""
import re
import sys

BEGIN = ("<!-- GENERATED:phases ROADMAP.md -> STATE.md | do not hand-edit "
         "| tools/check.sh --fix -->")
END = "<!-- END GENERATED:phases -->"
STATUS = re.compile(r"^(done \d{4}-\d{2}-\d{2}|todo)$")


def fail(msg):
    print("FAIL state-parity : %s" % msg)
    return 1


def read_phases():
    phases = []
    with open("ROADMAP.md", encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.startswith("| "):
                continue
            cols = [c.strip() for c in line.strip("|").split("|")]
            if len(cols) != 3 or cols[0] == "Phase" or cols[0].startswith("---"):
                continue
            phase, _what, status = cols
            if not phase:
                return None, "empty phase name"
            if any(p == phase for p, _ in phases):
                return None, "duplicate phase <%s>" % phase
            if not STATUS.match(status):
                return None, "bad status <%s> (want 'todo' or 'done YYYY-MM-DD)" % status
            phases.append((phase, status))
    if not phases:
        return None, "no phase rows in ROADMAP.md"
    return phases, ""


def want_block(phases):
    lines = ["- %s : %s" % (p, s) for p, s in phases]
    done = sum(1 for _, s in phases if s != "todo")
    lines.append("- %d/%d phases done" % (done, len(phases)))
    return lines


def main(fix):
    phases, err = read_phases()
    if phases is None:
        return fail(err)
    want = want_block(phases)
    with open("STATE.md", encoding="utf-8") as fh:
        text = fh.read()
    if BEGIN not in text or END not in text:
        return fail("GENERATED block markers absent (bootstrap them once by hand)")
    pre, rest = text.split(BEGIN, 1)
    mid, post = rest.split(END, 1)
    got = [l for l in mid.strip("\n").split("\n")]
    if got == want:
        print("ok state-parity : %d phases in sync" % len(phases))
        return 0
    if not fix:
        print("FAIL state-parity : STATE.md drifted from ROADMAP.md "
              "(run tools/check.sh --fix)")
        for line in want:
            if line not in got:
                print("  want: %s" % line)
        for line in got:
            if line not in want:
                print("  got:  %s" % line)
        return 1
    with open("STATE.md", "w", encoding="utf-8") as fh:
        fh.write(pre + BEGIN + "\n" + "\n".join(want) + "\n" + END + post)
    print("ok state-parity : regenerated %d phases" % len(phases))
    return 0


if __name__ == "__main__":
    sys.exit(main(len(sys.argv) > 1 and sys.argv[1] == "--fix"))
