---
type: ruling
status: active
roadmap: -
---

# Naming Q-N1..N3 — frozen identifiers, reservation protocol

Date: 2026-09-09 (reconstructed from `NAMES.md` + gates; original
naming chat history predates `decisions/` — amend here, append-only)
Status: active

## Problem

A rename in one place (GitHub slug, Maven coordinate, FML modid,
platform listing) silently breaks the others: the server drop stops
resolving, the modid collides in a shared instance, a platform slug
gets squatted. With 8 repos and 3 external platforms, tribal memory
does not scale.

## Decision

- Q-N1 — The GitHub slug is hosting only. Maven coordinates, FML
  modids, the SPI namespace and platform slugs are frozen in `NAMES.md`
  and never follow a repo rename.
- Q-N2 — `NAMES.md` is the SSOT: one 7-column row per repo
  (`tools/check.sh` refuses any row that is not 7 columns). Status
  `PROPOSED` means not yet reserved on the platform; `DRAFT` means a
  draft listing exists but no loadable mod release ships yet.
- Q-N3 — Strict reservation protocol before creating anything: probe
  the global slug (`curl .../modrinth.../<slug>` → 404 = free) plus a
  CurseForge search. Deliberate divergences stay frozen and documented:
  `matoubridge` vs legacy `matouengine` (migration cohabitation),
  `matouminimap` (`minimap` alone is taken everywhere),
  `quentin452/*` history frozen as-is, never renamed (JitPack/saves).

## Gates

- `tools/check.sh` names-table green (7 columns per row).
- Any rename ships `NAMES.md` in the same commit (`AGENTS.md` §4).

## What would re-open it

- A new publishable artifact (new mod, new platform): new row, same
  protocol, `PROPOSED` until reserved.
