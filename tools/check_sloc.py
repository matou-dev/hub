#!/usr/bin/env python3
"""Effective SLOC counter and ceiling checker (CatzEngineNext pattern).

Blank lines and full-line comments never count, trailing prose never zeroes
its code line. C-like: // splits outside string literals (escapes honored),
/* */ rides a small state machine. Shell: # splits outside single/double
quotes (escapes honored).

Pattern: CatzEngineNext gate_support::effective_sloc + sloc_cases.rs.
Doctrine: hub/decisions/EFFECTIVE_SLOC.md + AGENTS.md §3.
"""
import os
import sys

CEILING = 450


def code_part(line: str) -> str:
    """Strip a // comment that starts outside a string literal."""
    chars = list(line)
    n = len(chars)
    idx = 0
    in_str = False
    while idx < n:
        c = chars[idx]
        if in_str:
            if c == "\\":
                idx += 2
                continue
            if c == '"':
                in_str = False
            idx += 1
            continue
        if c == '"':
            in_str = True
            idx += 1
            continue
        if c == "/" and idx + 1 < n and chars[idx + 1] == "/":
            return line[:idx]
        idx += 1
    return line


def effective_sloc(content: str) -> int:
    """Effective SLOC of one source text: blank lines and comments never count."""
    count = 0
    in_block = False
    for line in content.splitlines():
        if in_block:
            if "*/" in line:
                in_block = False
            continue
        trimmed = code_part(line).strip()
        if not trimmed:
            continue
        if trimmed.startswith("/*"):
            if "*/" not in trimmed:
                in_block = True
            continue
        count += 1
    return count


def sh_code_part(line: str) -> str:
    """Strip a # comment that starts outside single/double quotes."""
    chars = list(line)
    n = len(chars)
    idx = 0
    quote = None
    while idx < n:
        c = chars[idx]
        if quote is not None:
            if c == "\\":
                idx += 2
                continue
            if c == quote:
                quote = None
            idx += 1
            continue
        if c in ("'", '"'):
            quote = c
            idx += 1
            continue
        if c == "#":
            return line[:idx]
        idx += 1
    return line


def effective_sh_sloc(content: str) -> int:
    """Effective SLOC of one shell text: blanks and #-comments never count."""
    count = 0
    for line in content.splitlines():
        if sh_code_part(line).strip():
            count += 1
    return count


def run_self_tests():
    """Exact test cases from CatzEngineNext/tools/catzc-next/tests/sloc_cases.rs."""
    # 1. blank_and_full_line_comments_never_count
    src1 = "// doc\n\nfn f() {\n    // trailing prose\n    1\n}\n"
    assert effective_sloc(src1) == 3, f"Case 1 failed: got {effective_sloc(src1)}"

    # 2. trailing_comment_keeps_its_code_line
    assert effective_sloc("let a = 1; // trailing\n") == 1

    # 3. slashes_inside_literals_stay_code
    assert effective_sloc('let u = "http://x";\n') == 1

    # 4. block_comments_skip_to_close
    src4 = "/* open\nstill comment\n*/\nfn f() {}\n"
    assert effective_sloc(src4) == 1, f"Case 4 failed: got {effective_sloc(src4)}"

    # 5. single_line_block_comment_never_counts
    assert effective_sloc("/* lone */\nfn f() {}\n") == 1

    # 6. escaped quotes in string
    assert effective_sloc('String s = "hello \\" // not comment";\n') == 1

    # 7. shell: full-line hash comments and blanks never count
    src7 = "#!/bin/sh\n# doc\n\necho hi\n"
    assert effective_sh_sloc(src7) == 1, f"Case 7 failed: got {effective_sh_sloc(src7)}"

    # 8. shell: trailing comment keeps its code line
    assert effective_sh_sloc("set -eu # strict\n") == 1

    # 9. shell: hashes inside quotes stay code
    assert effective_sh_sloc('echo "a#b"\n') == 1
    assert effective_sh_sloc("echo 'a#b'\n") == 1


def scan_sources(root_dir: str):
    """Scan all Java source files under src/ (excluding tests, tools, build)."""
    results = []
    for root, dirs, fnames in os.walk(root_dir):
        if any(skip in root for skip in [".git", "build", "target", "scratch", "/test", "/tools"]):
            continue
        if "/src" not in root:
            continue
        for fn in fnames:
            if fn.endswith(".java"):
                p = os.path.join(root, fn)
                with open(p, "r", encoding="utf-8") as fh:
                    content = fh.read()
                sloc = effective_sloc(content)
                raw = len(content.splitlines())
                rel = os.path.relpath(p, root_dir)
                results.append((sloc, raw, rel))
    results.sort(key=lambda x: x[0], reverse=True)
    return results


def scan_shell(root_dir: str):
    """Scan all shell scripts (*.sh) in the org (tools/ included)."""
    results = []
    for root, dirs, fnames in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in (".git", "build", "target")]
        for fn in fnames:
            if fn.endswith(".sh"):
                p = os.path.join(root, fn)
                with open(p, "r", encoding="utf-8") as fh:
                    content = fh.read()
                sloc = effective_sh_sloc(content)
                raw = len(content.splitlines())
                rel = os.path.relpath(p, root_dir)
                results.append((sloc, raw, rel))
    results.sort(key=lambda x: x[0], reverse=True)
    return results


def main():
    run_self_tests()
    if "--self-test" in sys.argv:
        print("ok (sloc-self-test : 10 cases passed)")
        return 0

    script_dir = os.path.dirname(os.path.abspath(__file__))
    org_root = os.path.abspath(os.path.join(script_dir, "../.."))
    results = scan_sources(org_root)
    sh_results = scan_shell(org_root)

    print("ok (sloc-self-test : 10 cases passed)")
    print(f"ok (sloc-scan : {len(results)} Java source files covered)")
    print(f"ok (sloc-scan-sh : {len(sh_results)} shell scripts covered)")

    print("\nTop files by effective SLOC (threshold: ~450 eSLOC):")
    print("%-60s | %-6s | %-6s" % ("File", "eSLOC", "Raw"))
    print("-" * 76)
    for sloc, raw, rel in results[:15]:
        flag = " *" if sloc >= CEILING else ""
        print("%-60s | %-6d | %-6d%s" % (rel, sloc, raw, flag))

    print("\nTop shell scripts by effective SLOC (threshold: ~450 eSLOC):")
    print("%-60s | %-6s | %-6s" % ("File", "eSLOC", "Raw"))
    print("-" * 76)
    over = 0
    for sloc, raw, rel in sh_results[:15]:
        flag = ""
        if sloc >= CEILING:
            flag = " *"
            over += 1
        print("%-60s | %-6d | %-6d%s" % (rel, sloc, raw, flag))
    if over:
        print(f"alert (sloc-ceiling : {over} shell script(s) >= {CEILING} eSLOC)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
