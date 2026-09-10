---
type: spec
status: active
maturity: prototype
scope: shared
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

- T4 pack-driven spawn/loot: landed (addendum below — the Mod holds
  zero `example1` imports).
- New sealed subsystem (third scope): new SPI roles holder +
  pack scope + seal, same shape — never a fifth genre smuggled in
  beside the roles.

## T4 pack-driven addendum (E0 green, no live re-proof)

The forge wire stayed content-aware for tables, job instantiation and
harvest kinds (`MatouBridgeMod`'s four `example1` imports) — the
explicit non-goal above. This tranche serves them through the pack
interface so the Mod drops all four imports:

- `spi` (`PolicyPack extends VocabularyPack`, pure, zero deps): plain
  data plus fresh jobs — `lootDrops()` (kind to content item ref,
  insertion-ordered, both served kinds paid), `lootOreKind()` /
  `lootBeastKind()` (event-classification kinds, always keys of the
  drops), `lootCount()` (positive), `spawnMob()` (qualified ref),
  `spawnHp/Cap/Budget/YMin/YMax()` (positive, ordered band),
  `lootJob()` / `spawnJob()` (fresh equivalents — `MatouJob` carries
  no id, so the pack serves instances, the moral equivalent of the
  `job(id)` registry). Content-blind: namespaces, kind names and
  numbers stay pack-owned, never in core.
- `example1` (`ExamplePack implements PolicyPack`): the owned file
  seals both tables at pack wire time (`fromFiles` — the tables' own
  multi/empty refusals propagate untouched), served beside the counts;
  count fixtures (int constructors, never wired to a file) serve no
  policy and refuse loudly under `E_EXAMPLE_POLICY:unwired` instead
  of guessing numbers. `ExampleCheck` provision battery: served values
  mirror `content/owned.matou`, drops immutable, unwired accessors
  refuse on all 15 probes.
- `bridge-1710` (`MatouBridgeMod`): `wireLoot` / `wireSpawn` read the
  first wire's pack through a `policy()` helper (`E_LOOT_POLICY` /
  `E_SPAWN_POLICY` refusals for non-policy packs, same shape as the T3
  `vocabulary()` helper); the kind-coverage rule moved with the data
  (`E_LOOT_TABLE:kind` when a served kind goes unpaid — a silent
  no-drop otherwise). Operator precedence unchanged (`OperatorPolicy`
  over served numbers, same effective values). The `no-lateral-import`
  etage-1 gate now covers `forge/src` (the T3 exemption comment named
  this exact re-opener).
- 4 bridges re-pinned to the SPI commit (no sibling forge change —
  lead-only behaviour, parity untouched; siblings keep their T3 gate
  text until ported).

No live re-proof (scaling-audit precedent): sealed outputs are
byte-identical by construction — same file parsed (owned), same table
maps, same counts through the same operator precedence, same job
classes deciding, same kinds recorded — and every decided path is
E0-locked (provision battery, seal-vs-job comparateurs, stub-compile
of the exact live bytes, `no-lateral-import` over `forge/src`).

Measured: `ExamplePack` grew 505 → ~600 lines (twelve delegating
accessors plus one guard, zero new branches — delegation, not
decision). The 450-line design alert from T3 now bites: the next
structural pass (table-driven jobs + policy holders out of the pack,
same file) is due before the next feature lands here — named, not
silent.

## Structural-pass amendment (E0 green, no live re-proof)

The T4 E0 battery probed policy only on the legacy 2-file path, while
the structure-wiring overloads rebuilt through the policy-free
constructor — so every structure-wired pack (including the live
`configure()` path) threw `E_EXAMPLE_POLICY:unwired` instead of serving
the seal. The "byte-identical, no live re-proof" claim above was wrong
for that path, and no live run has happened on T4 bytes to catch it
(proven E0-side with a scratch probe pre-fix, green post-fix — the next
structured live run on T4 bytes would have refused loud at `wireLoot`,
whose packs.cfg always combines ownedFile with structureFile).

Fix (example1 `73eadb8`, behaviour-preserving elsewhere):
`withStructures()` is the single structure-wiring tail and carries the
sealed tables across (same carry rule as the vein path, which already
did); `ExampleCheck` gains a policy comparateur asserting identical
sealed values across legacy / structured / configured-structured /
veined paths. Fusions in the same commit: `wiredPaths()` (the
`configure()` twin loops, byte-identical messages and order),
`singleton()` into `checked()` (identical refusal), `loot()` /
`spawn()` guards beside the data, `job(id)` over `jobs()` via `idOf()`
(the order lives in one place). Public API and `E_*` codes unchanged.

No live re-proof, on the corrected rationale: the legacy policy path is
live-proven (the loot/spawn proofs ran legacy packs) and the
comparateur locks the fixed paths to identical sealed values, which is
all the bridge reads through `PolicyPack`. Lesson recorded: the risk
was E0 coverage, not decided bytes — the battery now covers every
wiring path.

Measured floor: `ExamplePack` 600 → 637 lines (code 442 → 450, docs
117 → 142). The bulk is gate-pinned public surface (6 `fromFiles`
overloads, 4 ctors, 12 `PolicyPack` methods — every one called by E0
gates across 5 repos), not branch bloat: the remaining mirrors have
distinct contracts (`states()` seals counts, `jobs()` / `job()` serve
jobs) and are gate-locked. Under 450 needs cross-repo API narrowing (a
user decision), not another internal pass — the 450 alert is answered,
not stacked.

## T4 live proof (Forge 1614, structured path)

Landed after the amendment above (bridge-1710 `608b750`, host OpenJDK
1.8.0_502) : the "no live re-proof" rationale did not survive contact
with the server — the first structured run on T4 bytes died before any
policy read (`NoClassDefFoundError: ModelPig`, `SideOnly` stub without
`RUNTIME` retention, fixed + live-locked in the same tranche, see hub
`STATE.md` and `SPAWN.md`). Green since : 150s server run, bind clean,
world == pure union (1922 cells, ids 1,165) ; `LOOT=1` / `SPAWN=1`
direct client legs on structured ore-wire packs (carriers elapsed 1,
census 1→4, hp 20.0, spawn-to-loot chain through the served tables,
unions 1274, zero `E_*` refusals). The comparateur claim stands (fixed
paths serve identical sealed values) — it is now the second lock, not
the only one.

## Policy-holder extraction (E0 green, no live re-proof)

`ExamplePolicy` (example1 `b1f1428`, behaviour-preserving) : the sealed
loot/spawn tables plus the twelve `PolicyPack` accessors move out of
`ExamplePack` (637 → 606 lines, new 121-line holder), which delegates ;
wiring paths carry the holder by reference (same carry rule as the vein
path — structure/vein files never fund tables), count fixtures hold it
unwired. Public API, sealed values and `E_*` codes unchanged —
E0-locked by the provision battery and the policy comparateur over
every wiring path (legacy / structured / configured-structured /
veined) ; `ExampleCheck` unmodified, the 4 bridge gates green
unmodified (no bridge change : identical API, no re-pin, parity
untouched).

Measured : 606 lines still over the 450 alert — the holder took the
policy bulk, what remains is the gate-pinned surface (6 `fromFiles`
overloads, 4 ctors, 12 delegating accessors, docs). Under 450 still
needs the `fromFiles`-shim plus count-ctor narrowing — named next
pass, not stacked silently.
RETIRED 2026-09-11 (example1 `dc26617`) : canonical constructor
delegation, compact `fromFiles` overloads, and inline `PolicyPack`
accessors narrow `ExamplePack` 606 → 341 lines with zero API or error code
breakage. The 450-line design alert is closed.
