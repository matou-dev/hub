---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# Foundation Q-F1..Q-H1 — org + biting gates first, hub doctrine

Date: 2026-09-09 (reconstructed from history `5d33f04` + `ROADMAP.md`
F0/F1 rows; original chat history predates `decisions/`)
Status: active

## Problem

Content written before the org exists lands on no contract: no gate to
bite, no namespace to point at, no state file to update. The rework
costs more than the foundation ever did — measured the other way round
here: F0/F1 (org, 4 repos, biting `zero-mc-import` gates, hub doctrine,
`NAMES.md` repatriated) landed in one day and every later phase
(S1..E3, 27/27) built on it unchanged.

## Decision

- Q-F1 — Foundation first. Org + repos + biting gates (F0) before any
  syntax, skeleton or proof. A gate that has never caught a real bug is
  decoration: S1's goldens found a real parser bug before freeze, which
  is the standard every gate is held to (biting, not just green).
- Q-H1 — Hub carries the complete doctrine. This `AGENTS.md` alone
  governs the org; every other repo holds a one-line pointer here (or
  the GitHub URL as fallback). `STATE.md` is the present, `ROADMAP.md`
  the queue — a row is done only on green gates, never declared.
  Phase statuses are stated once (ROADMAP table, SSOT) and derived once
  (STATE GENERATED block, `tools/check.sh --fix`, never hand-edited).
  One finished unit (green gates) = one immediate local commit per
  touched repo; push goes through `tools/autopush.sh --execute`.

## Gates

- `tools/check.sh` green (hub-check, state-parity, bridge-parity).
- Every repo's `AGENTS.md` resolves here (sibling checkout or URL).

## What would re-open it

- A ninth repo: pointer file + doctrine rows, same shape, no new
  entry-point file.
