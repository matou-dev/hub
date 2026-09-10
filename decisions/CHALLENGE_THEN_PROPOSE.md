---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# Challenge-then-propose — always offer better than asked

Date: 2026-09-10 (operator ruling from chat; posture adapted from
CatzEngineNext `CHALLENGE_THEN_PROPOSE.md` — pointers re-pointed at this
org, never copied verbatim)
Status: active

## Problem

The agent executed literal requests even when a strictly better option
existed (simpler, generic, less debt, invariant-level). The user had to
spot the better path himself after the fact. Worst case: a literal
execution lands debt or a local solution that fragments the layering,
while the better path would have cost one question. Precedents in this
org: `AGENTS.md` section 5 already orders the long-term option first on
architectural questions, and section 3 already forces STOP plus evidence
on layering violations — but nothing generalizes the posture to every
request.

## Decision

1. Intent first: reformulate the request as destination (what the user
   wants to hold true), not as the path they named.
2. Judge the literal path before touching code: verdict against
   `LAYER_Q1_Q11.md`, `BRIDGE_PARITY.md`, `LIVE_PROOF_MODEL.md`, and the
   active specs (workspace grep; an audit citing no grep is invalid,
   `AGENTS.md` section 3).
3. If a strictly better option exists with evidence (measured, not
   taste): present intent + better proposal + why (one line each) +
   cost/delta, then ask before coding. Architectural tradeoff questions
   follow `AGENTS.md` section 5 (long-term first with `(Recommended)`; a
   workaround names its dated debt and is never recommended).
4. Never silently circumvent: one gate REJECT or layering violation =
   STOP + reframe or question, never a quiet workaround.
5. No challenge theater: pure execution with no tradeoff (no
   architectural cost, no invariant at stake) executes directly. Frozen
   specs (`REGISTRATION.md`, `VEIN_V4.md`, `LOOT.md`, `SPAWN.md`, all
   `status: direction`) and their locked build order are not
   re-challenged without new evidence (red gate or live measurement).
   Challenge only on evidence; never for style or preference.
6. Pointers only: this file owns the posture; `AGENTS.md` section 5 owns
   the question format. No copy either way.

## Gates

- `tools/check.sh` green, `tools/check.sh --fix` re-run exits 0 with no
  diff, `git status` clean after commit.

## What would re-open it

- Challenge theater twice (challenging with no evidence) or silent
  execution of a tradeoff twice: amend here, then propose a lint or
  template, not more prose.
