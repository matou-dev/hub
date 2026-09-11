---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# Effective SLOC — blank and comment lines never count

Date: 2026-09-11 (operator ruling from chat; precedent adapted from CatzEngineNext `docs/decisions/EFFECTIVE_SLOC.md`)
Status: active

## Problem

File size alerts (`AGENTS.md` §3 ~450 lines) counted raw lines (`wc -l` or editor line totals). Raw line counts tax documentation, javadocs, and whitespace — penalizing well-documented contracts. In `ExamplePack.java`, over 140 lines of Javadoc artificially pushed a 440-eSLOC file over the 600-line mark.

## Decision

1. **Definition.** Effective SLOC (eSLOC) of one source text: blank lines and full-line comments never count, trailing comments never zero their code line. C-like sources: `//` splits outside double-quoted strings (honoring `\"` escapes, preserving URLs in string literals); `/* */` and `/** */` ride a block-comment state machine. Shell sources (`*.sh`): `#` splits outside single/double quotes (honoring `\` escapes, preserving `a#b` in literals).
2. **Single home.** `hub/tools/check_sloc.py`, implementing `code_part(line)` and `effective_sloc(content)` (C-like) plus `sh_code_part(line)` and `effective_sh_sloc(content)` (shell), with built-in self-tests verifying the 6 canonical C-like boundary cases adapted from CatzEngineNext (`sloc_cases.rs`) plus 4 shell cases (full-line `#` skip, trailing-keeps-line, quoted `#` stays code).
3. **Threshold interpretation.** The ~450 lines design alert in `AGENTS.md` §3 is an architectural design metric evaluated in effective SLOC (eSLOC), not raw lines — for Java sources and shell scripts alike (`scan_shell` covers every `*.sh` in the org, `tools/` included; over-ceiling scripts print `alert (sloc-ceiling ...)`).

## Gates

- `hub/tools/check.sh` runs `check_sloc.py --self-test` (all 10 cases green).
- `hub/tools/check-decisions.sh` syncs the front-matter.
- Full `python3 hub/tools/check_sloc.py` reports Java + shell top files and the shell over-ceiling alert (advisory, exit 0 — same alert semantics as the Java `*` flags, deliberately not a hard gate until the 4 over-ceiling live/client scripts are refactored).
