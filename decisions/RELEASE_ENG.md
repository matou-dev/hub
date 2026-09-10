---
type: ruling
status: active
maturity: unrated
scope: shared
roadmap: -
---

# Release engineering — BUILD_ONLY dist, tags, DRAFT stores

Date: 2026-09-09 (R2 + v1.1.0 round)
Status: active

## Problem

A release cut from a dirty tree with hand-stamped jars is
unverifiable: no one can tell release bytes from dev bytes, and a
store listing published before any loadable mod exists promises
what the org cannot install. Both failure modes look fine until
someone downloads them.

## Decision

`BUILD_ONLY=1 VERSION=x.y.z` assembles `dist/` and exits before
booting (bridge `run-live.sh:20-21,61`): versioned jars (spi,
example1, minimap, reobf bridge) + content + `packs.cfg.example`
+ `SHA256SUMS`, self-verified with `sha256sum -c` before exit
(1710 `:255+`). Release bytes are self-describing: pins
(`SRG_MCP_SHA1` at 1710 `:41`, `MCP_CONFIG_SHA1` on modern),
Reobf MCP→SRG (`:220-226`, the MCP-named jar never ships), and
  the java-52 contract — 4 jars, no `module-info`, no
  multi-release entries, v52 loads on 8 and 21 alike, anything
  newer fails loudly (`:229-250`). v1.1.0 round: bridge-1710
  `114ee19` + bridge-1122 `cdd6baf` (structures drop, `@Mod`
  1.1.0 both bridges) over spi `0073226` seam; tags pushed
  (spi/1710 v1.0.0 + v1.1.0, 1122 v1.1.0); 3 GitHub releases (spi
  source + 2 server drops shipping `structure.matou`). v1.2.0 round
  (unified, ROADMAP R4): spi `3e819a9` (authoring surface,
  additive-only, retro `[1.1.0]` changelog section) + 4 bridges
  re-pinned to it (1710/1122 `@Mod` 1.2.0, 1201/1165 first drops at
  1.2.0 via the `mods.toml` `@VERSION@` stamp — no v1.0.0/v1.1.0
  tags on those repos); tags pushed (spi/1710/1122 v1.2.0, 1201/1165
  v1.2.0 first); 5 GitHub releases (spi source + 4 server drops
  shipping `structure.matou`).
Platform fiches stay DRAFT (`NAMES.md`: spi/example1/minimap
draft IDs, bridges never published alone) until a loadable mod
release exists — the bridge never ships solo, and R2 v1.0.0 set
  the precedent (source + server-drop only). 1201/1165 landed as
  first drops in the v1.2.0 round (same path, no new machinery).

## Gates

- `BUILD_ONLY` drops assembled + self-verified on both sides
  (pins, reobf, java-52, SHA256SUMS) before any tag.
- Tags pushed, GitHub releases cut from tag bytes only.

## What would re-open it

- The first store publish (any fiche leaving DRAFT): dedicated
  tranche with a loadable-mod gate, never a quiet flag flip.
- A dist layout change: the verifier (`sha256sum -c`) and the
  example packs.cfg template move together, same commit.
