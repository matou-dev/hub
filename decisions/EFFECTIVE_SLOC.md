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

1. **Definition.** Effective SLOC (eSLOC) of one source text: blank lines and full-line comments never count, trailing comments never zero their code line. `//` splits outside double-quoted strings (honoring `\"` escapes, preserving URLs in string literals); `/* */` and `/** */` ride a block-comment state machine.
2. **Single home.** `hub/tools/check_sloc.py`, implementing `code_part(line)` and `effective_sloc(content)` with built-in self-tests verifying the 5 canonical boundary cases adapted from CatzEngineNext (`sloc_cases.rs`).
3. **Threshold interpretation.** The ~450 lines design alert in `AGENTS.md` §3 is an architectural design metric evaluated in effective SLOC (eSLOC), not raw lines.

## Gates

- `hub/tools/check.sh` runs `check_sloc.py --self-test` (all 6 cases green).
- `hub/tools/check-decisions.sh` syncs the front-matter.
