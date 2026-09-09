---
type: ruling
status: active
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
   file.
2. Closed statuses: `done` (landed and frozen), `active` (live, carried
   by current code), `direction` (not yet coded), `parked` (explicitly
   waiting), `superseded` (replaced, successor named in the file).
   A landed-then-demolished decision is `parked`, never `done`.
3. Every `decisions/*.md` file carries a YAML front-matter block as its
   first lines: `type` plus `status` plus `roadmap`, where `roadmap` is a
   ROADMAP phase id or `-` when no ROADMAP row exists. Rulings, specs and
   directions never gain ROADMAP rows; the index tracks them.
4. The GENERATED block below is derived by `tools/check.sh --fix` from
   the front-matter (one section per type in closed type order, one row
   per file: file, status, roadmap), hand-off. Flat names keep every
   `decisions/` pointer stable, no subfolders.
5. Landing rule: the tranche that lands the first consumer of a
   `direction` flips its status to `active` in the same feat commit; the
   tranche that exhausts its order flips it to `done` (or names the
   successor for `superseded`).
6. To-write queue (hand-kept, below the GENERATED block): decisions
   identified as missing but not yet written. A queue entry is closed by
   landing the file, never by deleting the line.

<!-- GENERATED:decisions front-matter -> index | do not hand-edit | tools/check.sh --fix -->
### ruling
- DECISIONS_INDEX_AND_STATUS.md : active (roadmap -)
- DOCS_DEFINITION_OF_DONE.md : active (roadmap -)
- LAYER_Q1_Q11.md : active (roadmap -)
<!-- END GENERATED:decisions -->

## To-write queue

- [ ] `LAYER_Q1_Q11.md` (ruling) — layering zero-MC, cohabitation passive,
      owned/additive bypass, pure kernels, SPI+bridge/version, repo
      disjoint. Reconstruct from gates + code with `file:line` proofs.
- [ ] `NAMING_QN1_QN3.md` (ruling) — `matou-dev`, `NAMES.md` SSOT,
      strict reservation protocol.
- [ ] `FOUNDATION_QF1_QH1.md` (ruling) — foundation-first, hub doctrine.
- [ ] `SHARED_APPLY_SEAM_V1_1_0.md` (spec) — `fr.iamacat.bridge` seam in
      `matou-spi`, re-pointed bridges, `ForgeContentCheck` stays.
- [ ] `BRIDGE_PARITY.md` (ruling) — `SPI_PIN`, forge file-set, `E_FORGE_*`
      catalog, `tools/check-bridges.sh`.
- [ ] `BRIDGE_SCAFFOLD.md` (ruling) — `tools/scaffold-bridge.sh` template,
      N-bridge parity at scaffold.
- [ ] `DEV_CLIENT_SSOT.md` (ruling) — `hub/tools/run-client.sh` +
      `verify-client-save.sh`, `tools/client-common.sh` per-version table.
- [ ] `SCALING_AUDIT_STRUCTURAL_FIX.md` (note) — `Cell` + `Counts` +
      typed `Snapshot`, `ExampleIds` + pack `job(id)` registry,
      table-driven gates.
- [ ] `SYNTAX_V1_V2_V3.md` (spec) — SYNTAX freeze + goldens py+java,
      refusal parity.
- [ ] `STRUCTURES_CROSS_FILE.md` (spec) — `StructurePlaceJob`, recursive
      parts, palette aliases, `fromFiles` multi-file, parser-enforced
      imports.
- [ ] `LIVE_PROOF_MODEL.md` (ruling) — bind clean + world == pure union
      verdict, per-version notes (MCP/SRG, FAT, annotations, anvil).
- [ ] `RELEASE_ENG.md` (ruling) — tags, BUILD_ONLY dist, DRAFT stores.
- [ ] `HEADLESS_XVFB_QT_XCB.md` (ruling, pilot) — XVFB implies LAUNCH,
      Qt pinned to xcb, `WAYLAND_DISPLAY` dropped. Pairs with the
      uncommitted `tools/run-client.sh` fix.
