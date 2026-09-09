---
type: ruling
status: active
roadmap: -
---

# Layering Q1-Q11 — zero-MC submods, one bridge per version

Date: 2026-09-09 (reconstructed from gates + code; the original Q1-Q11
chat history predates `decisions/` and is lost — amend here, append-only,
if memory differs)
Status: active

## Problem

Four Minecraft versions must coexist in one org without any content or
client mod ever importing Minecraft classes, while each version still
gets a real in-game proof. Without a written seam, every new bridge or
submod guesses where Minecraft may be touched — and a wrong guess ships
a hard dependency that only explodes at runtime inside Forge.

## Decision

- Q1 — Passive 1.7.10 cohabitation, multi-version open. `matoubridge`
  deliberately differs from the legacy `matouengine` modid so both can
  load in one instance during migration (`NAMES.md:20-21`). Each bridge
  reuses modid `matoubridge`: safe, two bridges never load in the same
  MC instance (disjoint versions, `NAMES.md:22-23`).
- Q2 — Strict zero-MC layering for submods. `spi`, `example1`, `minimap`
  carry a `zero-mc-import` gate (their `tools/check.sh`); only the lib
  plus one bridge per version touches MC. Any existing or planned code
  contradicting this stops the tranche (`AGENTS.md` section 3).
- Q3-Q4 — Bypass for our own content. Owned content renders through the
  backend alone; non-owned content applies late and additive
  (`example1`: `content/owned.matou` 4 owned + `content/additive.matou`,
  pure `OwnedVeinJob` + `AdditiveScatterJob` + additive `merge`).
- Q5-Q9 — Pure kernels proven alone. `SpiBridge` decide→apply is pure
  with named `TODO(FORGE)`; `MinimapJob` renders overlay rows from SPI
  snapshots, never draws nor replaces vanilla, void explicit, loud
  refusals.
- Q6 — SPI plus one bridge per version. The shared apply seam lives in
  `matou-spi` (`fr.iamacat.bridge`, v1.1.0); each bridge re-points and
  drops its copies (see `SHARED_APPLY_SEAM_V1_1_0.md`, to-write queue).
- Q7-Q8 — Content proof (`example1`) and client proof (`minimap`) are
  separate repos, separate gates.
- Q10 — Additive cost is explicit: the merge comparator stays green and
  pins re-validate (re-pinned `00934e1`, bytes decided identical).
- Q11 — Disjoint repos. One repo per layer/version; sibling checkout,
  never vendored copies. `SPI_PIN` plus `tools/check-bridges.sh` refuse
  silent drift (pins, forge file-set, `E_FORGE_*` catalog).

## Gates

- `zero-mc-import` green in `spi`, `example1`, `minimap`.
- `no-legacy-matoulib` green in every `bridge-*`.
- `tools/check-bridges.sh` green over all bridges (same `SPI_PIN`,
  same forge file-set, same `E_FORGE_*` catalog).

## What would re-open it

- A fifth Minecraft version: new `bridge-*` repo, same gates, parity
  extended — never a second seam.
- A submod needing one MC class: STOP + user question, never a quiet
  `provided` import.
