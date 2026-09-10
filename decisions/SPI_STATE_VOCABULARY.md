---
type: spec
status: active
roadmap: -
---

# SPI state vocabulary — T3 shared registry, names outside core

Date: 2026-09-10
Status: active (first consumers: example1 provision + bridge-1710
vocabulary seals, E0 green 2026-09-10)

## Problem

The spawn/loot state vocabulary (`example1.spawn:*`,
`example1.loot:*`) was shared by lateral import: the bridge resolved the
ids it seals through the content's job classes. Measured
(`bridge-1710` pre-T3): `java/src/.../spawn/SpawnSeal.java:3`
(`SpawnJob`), `java/src/.../loot/LootSeal.java:3` (`LootJob`),
`forge/src/.../MatouBridgeMod.java:20-23` (tables + jobs). The shared
type lived under a consumer namespace, against `AGENTS.md` section 3
(shared types belong to the common base, never sideways) — and a second
content mod would force the translator to know every content by name.

## Decision

Generic mechanism in SPI, concrete names outside core:

- `fr.iamacat.spi.StateVocabulary` (pure, zero deps): an immutable
  descriptor — `of(namespace, names...)` over ordered distinct names,
  `namespace()` / `names()` / `id(name)`. Null, empty, duplicate,
  malformed and unknown names refuse loudly under `E_MATOU_VOCAB`,
  never defaulted. Shape validation reuses `MatouId.of` (one pattern
  owner, never re-stated).
- `fr.iamacat.spi.SpawnStates` / `LootStates` (pure, content-blind):
  the sealed-subsystem domain roles — census/table/cap/budget/y and
  harvested/table/count — plus the pack scopes (`spawn`/`loot`), a
  `vocabulary(namespace)` factory (roles in seal order, so sealed maps
  iterate identically live and in replay), and typed resolvers. Role
  literals exist exactly once, on these constants; no content
  namespace ever enters core.
- `fr.iamacat.spi.VocabularyPack extends ContentPack`:
  `vocabulary(scope)` serves the pack's vocabularies. The bridge
  resolves the seal ids from the reflectively loaded pack at wire time
  (parse-once, beside the tables — never on the tick path), keeping the
  B2 no-compile-edge contract (Q2): unknown scopes refuse loudly by the
  pack, a pack serving none refuses loudly by the wire.
- Explicit provision, never a static registry: a global mutable
  registry would couple seal reads to class-init order across jars
  (fragile) and leak state between gate batteries (untestable in
  isolation). The vocabulary is built once, carried explicitly (pack
  method, seal first parameter), resolved often.

Explicit non-goal for T3: the forge wire stays content-aware for
tables, job instantiation and harvest kinds (`MatouBridgeMod` keeps
its four `example1` imports) — that is the T4 pack-driven re-opener
below, not a quiet remainder.

## Landed shape (E0 green, no live re-proof)

- `spi` (`StateVocabulary` + `SpawnStates`/`LootStates` +
  `VocabularyPack`, `VocabularyCheck` gate: mechanism refusals,
  seal-ordered roles, cross-domain refusal, null battery).
- `example1` (`ExampleIds.SPAWN_NS`/`LOOT_NS`, `SpawnJob`/`LootJob`
  constants delegating through the shared vocabularies, `ExamplePack
  implements ConfigurablePack, VocabularyPack` — both interfaces, or
  the reflective `loadConfigured` path would stop configuring the pack
  — plus an `ExampleCheck` provision battery: served ids equal the job
  constants, unknown/null scope refuses).
- `bridge-1710` (`SpawnSeal`/`LootSeal` take the vocabulary first and
  resolve through the SPI resolvers — zero `example1` imports under
  `java/src`, held by a new etage-1 `no-lateral-import` refusal, tests
  exempt since the comparateur reads both sides; `PackWire.pack()`
  read-through; the Mod serves both vocabularies from the first wire's
  pack at wire time under `E_SPAWN_SEAL`/`E_LOOT_SEAL`-family refusals).
- 4 bridges re-pinned to the SPI commit (no forge change, no new
  `E_FORGE_*` — parity untouched).

No live re-proof (scaling-audit precedent): sealed outputs are
byte-identical by construction — same ids, same values, same insertion
order (asserted: seal keys follow the vocabulary order in both
comparateurs) — and every decided path is E0-locked (vocabulary
battery, seal-vs-job comparateurs at wired and overridden policies,
stub-compile of the exact live bytes). A live run would replay
identical decisions.

## Gates (prove the tranche)

- E0 pure green: `VocabularyCheck` (mechanism + roles), `ExampleCheck`
  provision battery, `SpawnCheck`/`LootCheck` (comparateurs over the
  provision path, null/wrong-vocabulary refusals, key-order
  assertion), etage 1 everywhere.
- Live-build replica green: stub-compile of `java/src` + stubs +
  `forge/src` against the new SPI.
- Parity green over 4 bridges (pins, file-set, `E_FORGE_*` catalog).

## Measured findings

- Re-pin cost of an SPI change is exactly four one-line commits (one
  per bridge) plus the parity gate — no code moves outside 1710,
  since siblings carry no spawn/loot/seal sources.
- `ExamplePack` was already at the 450-line design alert (477) when
  T3 added the 20-line delegating `vocabulary(scope)`: delegation,
  not a branch — the table-driven-jobs rule is untouched, but the
  file stays flagged for the next structural pass.

## What would re-open it

- T4 pack-driven spawn/loot: jobs, tables and harvest kinds served
  through the pack interface so `MatouBridgeMod` drops its four
  `example1` imports (tables behind plain-data accessors, jobs via
  the existing `job(id)` registry, kinds from the wire/table — never
  `LootJob.ORE` literals in the bridge). New pure fields + gate,
  addendum here.
- New sealed subsystem (third scope): new SPI roles holder +
  pack scope + seal, same shape — never a fifth genre smuggled in
  beside the roles.
