---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# Decisions index and status — typed front-matter plus derived table

Date: 2026-09-09
Status: active

## Problem

`docs/decisions`-style directories drift two ways: files exist that no
index names (orphans, invisible to fresh agents), and indexes name files
that no longer exist (dead pointers, trusted until they waste a session).
CatzEngineNext measured both in 2026-09 (46 orphans, stale statuses after
demolitions). This org starts at zero files, so the comparator must exist
before the first decision lands — otherwise the Full-mirror batch
recreates the exact drift it is supposed to fix.

## Decision

1. Closed types: `ruling` (permanent transverse rule), `spec` (contract
   before code), `direction` (target not yet coded), `note` (present-state
   note, no code change). No fifth type without a ruling amending this
   file. Deliberate divergence from CatzEngineNext (which gained `phase`
   plus `note-present` on 2026-09-10): our phases are `ROADMAP.md` rows,
   never files, and renaming `note` buys nothing — only the tracking
   columns below are adopted, not their type renames.
2. Closed statuses: `done` (landed and frozen), `active` (live, carried
   by current code), `direction` (not yet coded), `parked` (explicitly
   waiting), `superseded` (replaced, successor named in the file).
   A landed-then-demolished decision is `parked`, never `done`.
3. Every `decisions/*.md` file carries a YAML front-matter block as its
   first lines, canonical order `type`, `status`, `maturity`, `scope`,
   `roadmap`, where `roadmap` is a ROADMAP phase id or `-` when no
   ROADMAP row exists. Rulings, specs and directions never gain ROADMAP
   rows; the index tracks them.
   Closed maturity (quality of the carried live system, never the
   decision lifecycle — a `done` prototype stays a prototype):
   `prototype` (lead-bridge proof or partial coverage; never cited as a
   multi-bridge precedent) | `standard` (ported consumers, gates green
   on 2+ runtimes, known limits with named reopeners) | `production`
   (declared scope fully served, no known exception, admitted as
   precedent) | `unrated` (carries no live system of its own:
   transverse ruling, process, plan, note; never cited as precedent).
   Closed scope (primary home of the carried live system; rulings take
   the governed area): `spi` | `bridge` | `content` (example1 proofs) |
   `client` (minimap plus client-proof tooling) | `hub` (doctrine,
   gates, hub-owned tools) | `shared` (live system spanning several
   repos) | `unrated` (not yet evaluated).
4. The GENERATED block below is derived by `tools/check.sh --fix` from
   the front-matter (one section per type in closed type order, one row
   per file: file, status, maturity, scope, roadmap), hand-off. Flat names keep every
   `decisions/` pointer stable, no subfolders.
5. Landing rule: the tranche that lands the first consumer of a
   `direction` flips its status to `active` in the same feat commit; the
   tranche that exhausts its order flips it to `done` (or names the
   successor for `superseded`).
6. To-write queue (hand-kept, below the GENERATED block): decisions
   identified as missing but not yet written. A queue entry is closed by
   landing the file, never by deleting the line.
7. Landing rule for the tracking columns (extends rule 5): the tranche
   landing a system's first consumer rates it at minimum `prototype`
   with its real scope in the same feat commit — never `standard` or
   `production` by default. Promotion (`prototype` → `standard` →
   `production`) is its own tranche with the gates that prove the grade,
   never silent; skipping a grade is refused. `unrated` or `prototype`
   never justifies a new production-shaped system.

## Addendum — maturity plus scope columns (2026-09-10)

Adopted from CatzEngineNext (`DECISIONS_INDEX_AND_STATUS.md` addendum
2026-09-10, grades SSOT `SYSTEM_MATURITY_TRACKING.md` there): same two
closed keys, same canonical order, same landing rule — pointed here,
never copied. What is NOT adopted: their `phase`/`note-present` types
(see rule 1) and their scope values (`shell`/`game`/`shared` describe a
single engine repo; ours name the org repos, rule 3). Unlike Catz (211
of 218 files still `unrated` at adoption), every file below is rated in
the same commit that lands the columns — an adopted-but-unfilled column
is the same lie class as the Problem above.

<!-- GENERATED:decisions front-matter -> index | do not hand-edit | tools/check.sh --fix -->
### ruling
- BRIDGE_PARITY.md : active (maturity unrated, scope bridge, roadmap -)
- BRIDGE_SCAFFOLD.md : active (maturity unrated, scope bridge, roadmap -)
- CHALLENGE_THEN_PROPOSE.md : active (maturity unrated, scope hub, roadmap -)
- CI_SIBLING_REF_MAIN.md : active (maturity unrated, scope hub, roadmap -)
- DECISIONS_INDEX_AND_STATUS.md : active (maturity unrated, scope hub, roadmap -)
- DEV_CLIENT_SSOT.md : active (maturity unrated, scope client, roadmap -)
- DEV_LOOP.md : active (maturity unrated, scope hub, roadmap -)
- DIRECT_CLIENT_PROOF.md : active (maturity unrated, scope client, roadmap -)
- DOCS_DEFINITION_OF_DONE.md : active (maturity unrated, scope hub, roadmap -)
- EFFECTIVE_SLOC.md : active (maturity unrated, scope hub, roadmap -)
- FOUNDATION_QF1_QH1.md : active (maturity unrated, scope hub, roadmap -)
- HEADLESS_XVFB_QT_XCB.md : active (maturity unrated, scope client, roadmap -)
- LAYER_Q1_Q11.md : active (maturity unrated, scope shared, roadmap -)
- LIVE_PROOF_MODEL.md : active (maturity unrated, scope shared, roadmap -)
- MINECRAFT_BACKEND_REPRODUCIBILITY.md : active (maturity unrated, scope shared, roadmap -)
- NAMING_QN1_QN3.md : active (maturity unrated, scope shared, roadmap -)
- RELEASE_ENG.md : active (maturity unrated, scope shared, roadmap -)
### spec
- GL_INSTANCING_ADAPTER.md : active (maturity prototype, scope shared, roadmap -)
- ITEM_REGISTRATION.md : active (maturity standard, scope shared, roadmap -)
- LOOT.md : active (maturity standard, scope shared, roadmap -)
- MATOU_MODEL.md : active (maturity prototype, scope spi, roadmap -)
- REGISTRATION.md : active (maturity standard, scope shared, roadmap -)
- SHARED_APPLY_SEAM_V1_1_0.md : active (maturity standard, scope shared, roadmap -)
- SPAWN.md : active (maturity standard, scope shared, roadmap -)
- SPI_STATE_VOCABULARY.md : active (maturity standard, scope shared, roadmap -)
- STRUCTURES_CROSS_FILE.md : active (maturity standard, scope shared, roadmap -)
- SYNTAX_V1_V2_V3.md : active (maturity standard, scope shared, roadmap -)
- VEIN_V4.md : active (maturity standard, scope shared, roadmap -)
- VIRTUAL_HITBOXES.md : active (maturity prototype, scope spi, roadmap -)
### direction
- GPU_INSTANCING.md : active (maturity prototype, scope spi, roadmap -)
- REPOP_SPIKE.md : done (maturity standard, scope bridge, roadmap -)
### note
- SCALING_AUDIT_STRUCTURAL_FIX.md : active (maturity unrated, scope shared, roadmap -)
<!-- END GENERATED:decisions -->

## To-write queue

- [x] `LAYER_Q1_Q11.md` (ruling, landed 2026-09-09) — layering zero-MC, cohabitation passive,
      owned/additive bypass, pure kernels, SPI+bridge/version, repo
      disjoint. Reconstruct from gates + code with `file:line` proofs.
- [x] `NAMING_QN1_QN3.md` (ruling, landed 2026-09-09) — `matou-dev`, `NAMES.md` SSOT,
      strict reservation protocol.
- [x] `FOUNDATION_QF1_QH1.md` (ruling, landed 2026-09-09) — foundation-first, hub doctrine.
- [x] `SHARED_APPLY_SEAM_V1_1_0.md` (spec, landed 2026-09-09) —
      `fr.iamacat.bridge` seam in `matou-spi`, re-pointed bridges, `ForgeContentCheck` stays.
- [x] `BRIDGE_PARITY.md` (ruling, landed 2026-09-09) — `SPI_PIN`, forge file-set, `E_FORGE_*`
      catalog, `tools/check-bridges.sh`.
- [x] `BRIDGE_SCAFFOLD.md` (ruling, landed 2026-09-09) — `tools/scaffold-bridge.sh` template,
      N-bridge parity at scaffold.
- [x] `DEV_CLIENT_SSOT.md` (ruling, landed 2026-09-09) — `hub/tools/run-client.sh` +
      `verify-client-save.sh`, `tools/client-common.sh` per-version table.
- [x] `SCALING_AUDIT_STRUCTURAL_FIX.md` (note, landed 2026-09-09) — `Cell` + `Counts` +
      typed `Snapshot`, `ExampleIds` + pack `job(id)` registry,
      table-driven gates.
- [x] `SYNTAX_V1_V2_V3.md` (spec, landed 2026-09-09) — SYNTAX freeze + goldens py+java,
      refusal parity.
- [x] `STRUCTURES_CROSS_FILE.md` (spec, landed 2026-09-09) — `StructurePlaceJob`, recursive
      parts, palette aliases, `fromFiles` multi-file, parser-enforced
      imports.
- [x] `LIVE_PROOF_MODEL.md` (ruling, landed 2026-09-09) — bind clean + world == pure union
      verdict, per-version notes (MCP/SRG, FAT, annotations, anvil).
- [x] `RELEASE_ENG.md` (ruling, landed 2026-09-09) — tags, BUILD_ONLY dist, DRAFT stores.
- [x] `HEADLESS_XVFB_QT_XCB.md` (ruling, landed 2026-09-09 as catch-up
      on `a3097de`) — XVFB implies LAUNCH,
      Qt pinned to xcb, `WAYLAND_DISPLAY` dropped. Pairs with the
      `tools/run-client.sh` fix.
- [x] `DIRECT_CLIENT_PROOF.md` (ruling, landed 2026-09-09) — `tools/run-client-direct.sh`
       launcher-free automated client proof (landed in `fb1e600` with no
       decision — catch-up, same class as `a3097de`).
- [x] `CI_SIBLING_REF_MAIN.md` (ruling, landed 2026-09-09) — cross-repo
      checkouts pin `ref: main` (GITHUB_TOKEN 404s cross-repo default-branch
      lookup), self checkout unpinned, SHA pins checkout v7 + setup-java v6.
