---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# Docs Definition of Done + decisions-links guard

Date: 2026-09-09
Status: active

## Problem

Agents land code without writing the ruling it freezes, so a fresh agent
cannot reconstruct why the code is shaped that way. Measured 2026-09-09 in
this org: `ROADMAP.md:33-38` cites Q1-Q11, Q-N1..N3, Q-F1 and Q-H1 but no
`decisions/` directory exists — every one of those rulings is chat history,
lost at the next context rotation. Same day: `tools/run-client.sh` carries
an uncommitted XVFB/Qt-xcb headless fix with no decision file anywhere, and
`STATE.md:38-49` records a shared apply seam (`fr.iamacat.bridge` v1.1.0),
a 4-bridge parity model and a dev-client generalization, none of them
pointed from `AGENTS.md`. Root causes: `AGENTS.md:28-29` points at a prose
`ROADMAP.md` context line with no existence comparator, and no checklist
requires a decision file per tranche.

## Decision

1. Every tranche that freezes a concept creates or updates a
   `decisions/<NOM>.md` file in the SAME feat commit as the code (matou
   same-commit rule, `AGENTS.md` section 4 — not the CatzEngineNext
   feat+sync pair, which exists only because Catz derives STATE/LAYOUT).
   A tranche with no created-or-updated `decisions/*` file is incomplete.
2. `AGENTS.md` section 2 keeps no per-file decision list. The existence
   index is the GENERATED block of
   `decisions/DECISIONS_INDEX_AND_STATUS.md` (one file one line with its
   H1 title, owned by `tools/check.sh --fix`). Topic pointers live at
   their use site, never as an exhaustive list in `AGENTS.md`.
3. Pre-commit sweep: grep the identifier, constant or path moved across
   `*.md` and comments — a doc naming what just moved now lies.
4. `tools/check-decisions.sh` guard (wired into `tools/check.sh`): every
   `decisions/*.md` token across `*.md` must name a file on disk — loud
   FAIL with `file:line`, never a silent skip. Front-matter type/status/
   maturity/scope must stay in the closed sets of `DECISIONS_INDEX_AND_STATUS.md`.

## Gates

- `tools/check.sh` green, `tools/check.sh --fix` re-run exits 0 with no
  diff, `git status` clean after commit.
- Pre-fix check must be red only on decisions drift (missing GENERATED
  block, dead `decisions/` link, out-of-vocabulary front-matter).

## What would re-open it

- A prose doc the guard cannot see goes stale twice: propose a derived
  field or a new named gate then, not more prose.
- Index unreadable past ~100 files: split the index, keep one home.
