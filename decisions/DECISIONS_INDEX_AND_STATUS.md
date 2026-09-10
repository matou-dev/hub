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
- BRIDGE_PARITY.md : active (roadmap -)
- BRIDGE_SCAFFOLD.md : active (roadmap -)
- CHALLENGE_THEN_PROPOSE.md : active (roadmap -)
- CI_SIBLING_REF_MAIN.md : active (roadmap -)
- DECISIONS_INDEX_AND_STATUS.md : active (roadmap -)
- DEV_CLIENT_SSOT.md : active (roadmap -)
- DEV_LOOP.md : active (roadmap -)
- DIRECT_CLIENT_PROOF.md : active (roadmap -)
- DOCS_DEFINITION_OF_DONE.md : active (roadmap -)
- FOUNDATION_QF1_QH1.md : active (roadmap -)
- HEADLESS_XVFB_QT_XCB.md : active (roadmap -)
- LAYER_Q1_Q11.md : active (roadmap -)
- LIVE_PROOF_MODEL.md : active (roadmap -)
- NAMING_QN1_QN3.md : active (roadmap -)
- RELEASE_ENG.md : active (roadmap -)
### spec
- LOOT.md : active (roadmap -)
- REGISTRATION.md : active (roadmap -)
- SHARED_APPLY_SEAM_V1_1_0.md : active (roadmap -)
- SPAWN.md : active (roadmap -)
- STRUCTURES_CROSS_FILE.md : active (roadmap -)
- SYNTAX_V1_V2_V3.md : active (roadmap -)
- VEIN_V4.md : active (roadmap -)
### direction
- REPOP_SPIKE.md : done (roadmap -)
### note
- SCALING_AUDIT_STRUCTURAL_FIX.md : active (roadmap -)
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
