#!/usr/bin/env python3
"""Effective SLOC counter and ceiling checker (CatzEngineNext pattern).

Blank lines and full-line comments never count, trailing prose never zeroes
its code line. // splits outside string literals (escapes honored), /* */
rides a small state machine.

Pattern: CatzEngineNext gate_support::effective_sloc + sloc_cases.rs.
Doctrine: hub/decisions/EFFECTIVE_SLOC.md + AGENTS.md §3.
"""
import os
import sys


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


def main():
    run_self_tests()
    if "--self-test" in sys.argv:
        print("ok (sloc-self-test : 6 cases passed)")
        return 0

    script_dir = os.path.dirname(os.path.abspath(__file__))
    org_root = os.path.abspath(os.path.join(script_dir, "../.."))
    results = scan_sources(org_root)

    print("ok (sloc-self-test : 6 cases passed)")
    print(f"ok (sloc-scan : {len(results)} Java source files covered)")

    print("\nTop files by effective SLOC (threshold: ~450 eSLOC):")
    print("%-60s | %-6s | %-6s" % ("File", "eSLOC", "Raw"))
    print("-" * 76)
    for sloc, raw, rel in results[:15]:
        flag = " *" if sloc >= 450 else ""
        print("%-60s | %-6d | %-6d%s" % (rel, sloc, raw, flag))

    return 0


if __name__ == "__main__":
    sys.exit(main())
