# STATE.md — présent

- 2026-09-12 : Beast texture V2 E0, lead bridge-1122 (spi `806411d`
  per-face unwrap + `GlBackend` texture surface, bridge-1122 `00f9ce4`
  textured renderer + `BeastTexture` + 64x64 asset, hub addenda in
  `MATOU_MODEL.md` + `GL_INSTANCING_ADAPTER.md`, `PORT_QUEUE`
  `TODO | e0 | TODO | TODO`) : stages 1-2 green (spi checks incl.
  per-face goldens + `E_MODEL_FACE` battery + texture mock workflow,
  lead `ModelWireCheck` texture battery + forge + autoplay compile,
  sibling backend-conformance + pins `806411d` E0 green each, parity
  catalog unchanged) ; box-uv assets bake byte-identical (existing
  goldens unmodified) ; zero new MC surface (stub rows only). Live
  proof TODO — same bar as every lead E0 (150 s server + `SPAWN=1
  COMBAT=1` textured-draw legs). Siblings dispatch TODO.
- 2026-09-12 : GPU_INSTANCING promoted prototype → standard (hub
  `decisions/GPU_INSTANCING.md` : front-matter flip, `What remains`
  items 1-2 closed live x4, item 3 stays the named non-goal — engine
  GL 4.5 path never ported) :
  - Quality justification: render plan adapter live-proven
    version-native on 4/4 Forge runtimes (1710/1122 LWJGL2, 1165/1201
    LWJGL3 — `ready mesh=72 verts stride=8`, `drew instances=1
    buckets=1` through the seal, `E_GL_DRAW` silent, worlds == pure
    union 1922, saves pure union 1274, zero `E_*` / linkage, all
    gates green), 0 shells, parity gap declared (1165/1201
    join-transient guard reuses cited `E_RENDER_FRUSTUM`, 1 local
    code each, gate green).
  - `DECISIONS_INDEX_AND_STATUS.md` regenerated via `tools/check.sh
    --fix` ; `check.sh` passes green.
- 2026-09-12 : Render plan adapter dispatch live, siblings
  1710/1165/1201 (1710 `4e25e2a` zero live fixes, 1165 `6c248e7` +
  `01470b6` rewind + join-transient guard, 1201 `ac31b4c` +
  `565be27` join-transient guard, hub `decisions/GPU_INSTANCING.md`
  live addendum, `PORT_QUEUE` `live | live | live | live` — row
  closed) : 150 s servers green each (worlds == pure union 1922,
  zero `E_*`) ; headless direct-clients `SPAWN=1 COMBAT=1` (exit 0
  each, `NUMERIC_IDS=example1:my_ore=165` on 1710) — `ready mesh=72`
  + `drew instances=1 buckets=1` through the seal each, census 2→8,
  hp 20.0 + 30.0, exact-2.0 at 500→501 then exact-3.0 at 600→601
  (elapsed 1 each), kill 1000 → gem 1001 (elapsed 1) with same-tick
  replacement, saves pure union 1274, zero `E_*` (benign per-runtime
  `Caused by` only). Guard reuses cited `E_RENDER_FRUSTUM`
  (1165/1201 1 local code each, gate green) ; LWJGL2 reads show no
  transient so the lead keeps none. No open item remaining on the
  row.
- 2026-09-11 : Render plan adapter live, lead bridge-1122
  (`4119639` E0, zero live fixes, hub `decisions/GPU_INSTANCING.md`
  live addendum, `PORT_QUEUE` `TODO | live | TODO | TODO`) : 150 s
  server green (world == pure union 1922, zero `E_*`) ;
  headless direct-client `NUMERIC_IDS=example1:my_ore=253 SPAWN=1
  COMBAT=1` (exit 0) — `ready mesh=72` + `drew instances=1 buckets=1`
  through the seal (GL accepted, `E_GL_DRAW` silent), census 2→8
  balanced, hp 20.0 + 30.0, exact-2.0 at 500→501 then exact-3.0 at
  600→601 (elapsed 1 each), kill 1000 → gem 1001 (elapsed 1) with
  same-tick replacement, save pure union 1274, zero `E_*` (benign
  gem-model `Caused by` only, same as every 1122 proof). Three
  dispatch ports TODO — last open item on the row.
- 2026-09-11 : Render plan adapter E0, lead bridge-1122 (spi
  `89406af` `RenderStates` + `ViewProjection` + gate batteries,
  bridge-1122 `4119639` `RenderJob` + `RenderSeal` + `RenderWireCheck`
  + per-bucket draw, hub `decisions/GPU_INSTANCING.md` addendum,
  `PORT_QUEUE` `TODO | e0 | TODO | TODO`) : stages 1-2 green
  (spi checks incl. `ok render-plan : 589 checks`, bridge E0 incl.
  forge-stub + autoplay-compile, SPI pins `89406af` x4) ; zero
  behaviour change for fully visible scenes (mob-addressed buckets
  over the shared mesh, same upload bytes, `drew instances=` kept) ;
  zero new MC surface (no stub or narrow-map delta). Live proof TODO
  — same bar as every lead E0 (150 s server + `SPAWN=1 COMBAT=1`
  wired-draw legs). Siblings re-pinned only (dispatch ports TODO).

- 2026-09-12 : Qualified mob view sibling live, bridge-1201
  (`de4f525`, zero live fixes, hub `decisions/SPAWN.md` addendum —
  row closed live x4) : 150 s server green (world == pure union 1922
  `example1:my_ore`+stone, per-mob spawn+combat wire, zero `E_*`) ;
  headless direct-client `SPAWN=1 COMBAT=1` (exit 0 end to end, no
  `NUMERIC_IDS` flattening era) — census 2→8 at worldTicks 1..4, hp
  20.0 + 30.0, beast head x2 → 18.0 at 501 then brute head x3
  (drop=3.0 exact → 27.0 at 601, full-health baseline this run — no
  ambient churn, proving the 1710/1165 damaged baselines
  run-dependent), kill 1000 → gem 1001 (elapsed 1) with the replacement
  joining the same tick 1000 under `example1.content:my_beast`, clean
  shutdown (game exited 0, save pure union 1274), zero `E_*` (single
  benign `Caused by` = vanilla flite narrator, same as every 1201
  proof). Trouvaille machine-locale: `/tmp` is tmpfs so the wipe took
  the old `/tmp/jdk17` — re-extracted same Temurin 17.0.20 bytes from
  the cached `matou-live-1201` image, never committed. No open item
  remaining on the row.

- 2026-09-12 : Qualified mob view sibling live, bridge-1165
  (`417b5f5`, zero live fixes, hub `decisions/SPAWN.md` addendum) :
  150 s server green (world == pure union 1922
  `example1:my_ore`+stone, per-mob spawn+combat wire, zero `E_*`, no
  `Caused by`) ; headless direct-client `SPAWN=1 COMBAT=1` (exit 0 end
  to end, no `NUMERIC_IDS` flattening era) — census 2→8 at worldTicks
  1..4, hp 20.0 + 30.0, beast head x2 → 18.0 at 501 then brute head x3
  (drop=3.0 exact at 601, baseline 19.0 ambient-damaged — same
  deterministic churn at ticks 308/324 as the 1710 runs), kill 1000 →
  gem 1001 (elapsed 1) with the replacement joining the same tick 1000
  under `example1.content:my_beast`, clean shutdown (game exited 0,
  save pure union 1274), zero `E_*` / linkage / `Caused by`. 1201
  sibling live stays TODO — last open item on the row.

- 2026-09-12 : Qualified mob view sibling live, bridge-1710
  (`5dc3a2a`, zero live fixes, hub `decisions/SPAWN.md` addendum) :
  150 s server green (world == pure union 1922 ids 1,165, zero
  `E_*`) ; headless direct-client `NUMERIC_IDS=example1:my_ore=165
  SPAWN=1 COMBAT=1` (exit 0 end to end) — census 2→8, hp 20.0 +
  30.0, beast head x2 → 18.0 at 501 then brute head x3 (drop=3.0
  exact, elapsed 1 each), kill 1000 → gem 1001 (elapsed 1) with the
  replacement joining under `example1.content:my_beast`, clean
  shutdown at 4600 ticks, save pure union 1274, zero `E_*` /
  linkage. Trouvailles: struck-brute baseline reads ambient-damaged
  (18.0/19.0 across runs, churn at ticks 308/324 — drop stays
  exact) ; the internal verdict inherits `NUMERIC_IDS` from env, so
  the era-native id rides the invocation (same as every 1710
  proof). 1165+1201 sibling live stays TODO — last open item on
  the row.

- 2026-09-11 : Qualified mob view lead live, bridge-1122
  (`3338075`, zero live fixes, hub `decisions/SPAWN.md` addendum) :
  150 s server green (world == pure union 1922, zero `E_*`) ;
  headless direct-client `SPAWN=1 COMBAT=1` (exit 0) — census 2→8,
  hp 20.0 + 30.0, exact-2.0 at 500→501 then exact-3.0 at 600→601
  (elapsed 1 each), kill 1000 → gem 1001 (elapsed 1) with the
  replacement joining under `example1.content:my_beast`, clean
  shutdown at 4600 ticks, save pure union 1274, zero `E_*` /
  linkage. Sibling live 1710 done 2026-09-12, 1165+1201 TODO —
  last open item on the row.

- 2026-09-11 : Qualified PolicyPack mob view E0, all bridges (spi
  `f1499ee` `PolicyPack.spawnMobRef`, example1 `63ff7b7`
  `SpawnTable.mobRef` + delegates + battery, bridges 1710 `5dc3a2a`
  + 1122 `3338075`   + 1165 `417b5f5` + 1201 `de4f525` wire swap +
  `contentNamespace()` deleted, hub `decisions/SPAWN.md` addendum,
  `LOOT.md` staying-open line closed) : stages 1-2 green everywhere
  (spi checks, example1 535 oks, 4 bridge gates incl. forge +
  autoplay compile, SPI pins `f1499ee` x4, parity catalog
  unchanged) ; zero behaviour difference proven by battery (same
  qualified strings, same map keys). Live proof TODO — same bar as
  every E0 (lead 150 s server + `SPAWN=1 COMBAT=1` legs, then
  ports). No open follow-up remains on any per-mob row.

- 2026-09-11 : Shell ceiling defused on bridge-1201 (bridge-1201
  `2ceec2f` table-driven pin groups, zero logic change —
  `tools/run-live.sh` 449→431 eSLOC, 19 under the 450 hard ceiling,
  same margin as the 1165 wrapper) : 7 loop hunks over homogeneous
  pin groups (Entity/Vec3i getX/Y/Z, Entity xo/yo/zo/yRotO/xRotO,
  registry pairs, BlockEvent triple, RenderLevelStageEvent quad,
  Level game-pin triple — names stay literal and grep-able), 112 pin
  calls expand identical before/after (stub-expansion proof, zero
  divergence) ; bridge `tools/check.sh` green, hub `tools/check.sh`
  green (parity pin `f48d37e`, sloc-ceiling ok). Closes the 449/450
  fragile flag (older bullets stay dated records).

- 2026-09-11 : Distinct per-mob drops ports live, bridge-1165 +
  bridge-1201 (bridge-1165 `447ad10` + bridge-1201 `cab4981` per-mob
  loot wire + autoplay, SPI pin untouched, hub `decisions/LOOT.md`
  ports addendum, `PORT_QUEUE` `live | live | live | live`) : servers
  150 s green each (world == pure union 1922, loot wired per-mob with
  counts `{ore=1, beast.my_beast=1, beast.my_brute=2}`, both gems
  registered each, zero `E_*`) ; `LOOT=1` direct-client legs (exit 0
  each) — ore 1000→gem 1001, beast 1005→gem 1006, brute
  1010→brute-gem x2 at 1011 (elapsed 1 each), union 1274 (native
  names, no `NUMERIC_IDS` on these flattening eras) ;
  `SPAWN=1 COMBAT=1` regression legs (exit 0 each) — census 2→8
  balanced, hp 20.0 + 30.0, exact-2.0 at 500→501 then exact-3.0 at
  600→601, spawn kill pins `my_beast` → gem elapsed 1, union 1274
  (1201 single benign `Caused by` = vanilla flite narrator, same as
  every 1201 proof). Trouvailles: per-mob wire pays ambient dim-0
  falls too (1201 tick-73 falls paid per-mob, entities only) ; 1201
  host has no Java 17 (machine-local Temurin + docker cache copy,
  never committed). Only the qualified mob view stays a named
  follow-up.

- 2026-09-11 : Distinct per-mob drops port live, bridge-1710
  (bridge-1710 `f85eb70` per-mob loot wire + autoplay, SPI pin
  untouched, hub `decisions/LOOT.md` port addendum, `PORT_QUEUE`
  `live | live | TODO | TODO`) : server 150 s green (world == pure
  union 1922 ids 1,165, loot wired per-mob with counts `{ore=1,
  beast.my_beast=1, beast.my_brute=2}`, both gems registered, zero
  `E_*`) ; `LOOT=1` direct-client leg (exit 0) — ore 1000→gem 1001,
  beast 1005→gem 1006, brute 1010→brute-gem x2 at 1011 (elapsed 1
  each), union 1274 (`1,165` via `NUMERIC_IDS`) ; `SPAWN=1 COMBAT=1`
  regression leg (exit 0) — census 2→8 balanced, hp 20.0 + 30.0,
  exact-2.0 at 500→501 then exact-3.0 at 600→601, spawn kill pins
  `my_beast` → gem elapsed 1, union 1274. Two ports and the qualified
  mob view stay named follow-ups.

- 2026-09-11 : Distinct per-mob drops live, lead bridge-1122
  (bridge-1122 `8aebc3b` per-mob autoplay + beast-pinned spawn kill,
  zero forge change, hub `decisions/LOOT.md` live addendum,
  `PORT_QUEUE` `TODO | live | TODO | TODO`) : server 150 s green
  (world == pure union 1922, loot wired per-mob with counts
  `{ore=1, beast.my_beast=1, beast.my_brute=2}`, both gems
  registered, zero `E_*`) ; `LOOT=1` direct-client leg (exit 0) —
  ore 1000→gem 1001, beast 1005→gem 1006, brute 1010→brute-gem x2
  at 1011 (elapsed 1 each), union 1274 (`1,253` via `NUMERIC_IDS`)
  ; `SPAWN=1 COMBAT=1` regression leg (exit 0) — census 2→8
  balanced, hp 20.0 + 30.0, exact-2.0 at 500→501 then exact-3.0 at
  600→601, spawn kill pins `my_beast` → gem elapsed 1, union 1274.
  Trouvaille: the client verifier reads y=63..65 only, so ore-wire
  loot legs drop `veinFile` (else 648 vein cells missing) with the
  dynamic ore id via `NUMERIC_IDS`. Three ports and the qualified
  mob view stay named follow-ups.

- 2026-09-11 : Distinct per-mob drops E0, lead bridge-1122 (spi
  `f48d37e` per-mob loot views, example1 `9a874a6` `my_brute_gem`
  x2 + per-mob `LootTable`/`LootJob`, bridge-1122 `b6a3959` per-mob
  loot wire, hub `decisions/LOOT.md` addendum, `PORT_QUEUE`
  `TODO | e0 | TODO | TODO`) : stages 1-2 green (example1 534 ok,
  bridge-1122 per-mob batteries, forge + autoplay compile), live
  proof TODO — same bar as every lead E0. `my_beast` pays
  `my_gem` x1, `my_brute` pays `my_brute_gem` x2, ore pays the first
  sealed mob ; the `E_EXAMPLE_LOOT:diverged` refusal is retired
  (divergent content seals per mob). Siblings oracle-backported only
  (1710 `fc5fce6`, 1165 `a24d888`, 1201 `dcd5a1c` — oracles read
  per-mob, seals stay single-kind, sole-view multi refusal pinned as
  the dispatch-port rationale), E0 green each, zero forge dispatch.
  Live (150 s server + per-mob kill legs) and the qualified mob view
  stay named follow-ups.

- 2026-09-11 : Per-mob operator override ports live x4 (bridge-1710
  `bd547ad`, bridge-1165 `353ffc9`, bridge-1201 `1de261f`, zero live
  fixes, hub `decisions/VIRTUAL_HITBOXES.md` port addenda,
  `PORT_QUEUE` `live | live | live | live`) : 150 s servers green each
  (pure union 1922, zero `E_*`, 25565 races retried green) ; two
  headless direct-client legs each (default + `combat.reach.my_brute`
  override, exit 0 each) — identical exact-2.0 + exact-3.0 both legs,
  saves pure union, zero `E_*`. Era-blind confirmed (lead pure files
  byte-identical). 0 `TODO` remaining on the row, never silent.

- 2026-09-11 : Per-mob operator override E0+live, lead bridge-1122
  (bridge-1122 `823cda5`, zero live fixes, hub
  `decisions/VIRTUAL_HITBOXES.md` addendum, `PORT_QUEUE`
  `TODO | live | TODO | TODO` new row) : stages 1-2 green (per-mob
  batteries, forge + autoplay compile), 150 s server green (world ==
  pure union 1922, byte-identical wire lines, zero `E_*`) ; two
  headless direct-client legs (exit 0 each) — default exact-2.0 at
  500→501 + exact-3.0 at 600→601, override leg
  (`combat.reach.my_brute=6.0`) identical with the win named, saves
  pure union, zero `E_*`. Trouvaille: SPI seam key-agnostic, whole
  operator vocabulary bridge-side — no SPI change. Three ports TODO.

- 2026-09-11 : Second beast ports live on bridge-1165 + bridge-1201
  (bridge-1165 `0aca413`, bridge-1201 `2ee4033`, zero live fixes, hub
  `decisions/VIRTUAL_HITBOXES.md` port addenda, `PORT_QUEUE`
  `live | live | live | live` both rows) : 150 s servers green each
  (worlds == pure union 1922, per-mob wire lines, zero `E_*`, 25565
  bind-races retried green) ; headless direct-clients `SPAWN=1
  COMBAT=1` (exit 0 each) — census 8 balanced, hp 20.0 + 30.0,
  exact-2.0 at 500→501 then exact-3.0 at 600→601 (elapsed 1 each, chain
  intact, saves pure union 1274, zero `E_*` / linkage). Four ports
  live, 0 `TODO` remaining, never silent. Trouvailles: 1165
  `run-live.sh` at 431/450 eSLOC, 1201 at 449/450 (next shell growth
  table-driven) ; Pig-level persist helpers `public` on all three
  ports (lead `protected`).

- 2026-09-11 : Second beast port live on bridge-1710 (bridge-1710
  `19378d4`, zero live fixes, hub `decisions/VIRTUAL_HITBOXES.md` port
  addendum, `PORT_QUEUE` `live | live | TODO | TODO` both rows) : 150 s
  Forge 1614 server green (world == pure union 1922, per-mob wire
  lines, zero `E_*`) ; headless direct-client `SPAWN=1 COMBAT=1`
  (exit 0) — census 8 balanced, hp 20.0 + 30.0, exact-2.0 at 500→501
  then exact-3.0 at 600→601 (elapsed 1 each, chain intact, save pure
  union 1274, zero `E_*` / linkage). Trouvaille: 1614 `EntityPig`
  declares persist helpers `public` (lead `protected` — override widens,
  same owner class). 1165/1201 code green, live unblocked by the shared
  derive 54→59 bump (next).

- 2026-09-11 : Second beast live, lead bridge-1122 (bridge-1122
  `eab8e0e` NBT helpers + per-mob autoplay + 53-line narrow map, hub
  `decisions/VIRTUAL_HITBOXES.md` live addendum, `PORT_QUEUE`
  `TODO | live | TODO | TODO` both second-beast rows) : server 150 s
  green (bind clean, world == pure union 1922, `registered-entity
  <my_beast,my_brute>`, per-mob spawn+combat wire lines, zero `E_*`) ;
  headless direct-client `SPAWN=1 COMBAT=1` (exit 0) — census 2→8 at
  worldTicks 2..5 (beast=brute, cap 4+4), hp 20.0 + 30.0, exact-2.0 at
  500→501 then exact-3.0 at 600→601 (elapsed 1 each, chain intact),
  kill 1000 → carrier 999 → polled 1001, client save pure union 1274,
  zero `E_*` / linkage (two benign gem-model `Caused by`, same as every
  1122 proof). Trouvaille (owner-discipline class): the public
  `writeToNBT`/`readFromNBT` super calls emit the intermediate
  `EntityPig` owner no narrow-map row can cover (`E_MAP_COVER` refused
  before the first boot) — the beast overrides the Pig-declared
  `writeEntityToNBT`/`readEntityFromNBT` helpers instead (same 5-row
  delta, mappable). Siblings keep refusing 2-mob content loudly
  (`E_REG_BEAST`), which is the dispatch-port rationale. Per-mob
  operator keys, distinct per-mob drops and the qualified mob view stay
  named follow-ups.

- 2026-09-11 : Second beast registration E0, lead bridge-1122
  (example1 `5397dd0` `SpawnTable.mobRefs()` qualified mob list,
  bridge-1122 `6a50517` one generic registration over every sealed
  mob, hub `decisions/VIRTUAL_HITBOXES.md` registration addendum,
  `PORT_QUEUE` `TODO | e0 | TODO | TODO`) : stages 1-2 green
  (example1 507 ok, bridge-1122 211 ok, forge + autoplay compile),
  live proof TODO — same bar as every lead E0. The registry name
  rides the first sealed mob (file order — single-mob tables
  register byte-identical bytes and log the byte-identical
  `registered-entity <mob>` line, multi logs `<m1,m2>`) ; the NBT
  identity distinguishes the beasts at runtime (no second
  mod-local id, no new code). Siblings untouched (no SPI change,
  no forge-side oracle to backport) — their `Example1Mod` keeps
  refusing the 2-mob content loudly, which is the dispatch-port
  rationale. Live blocked loud, not silent: NBT narrow-map delta
  (~5 `want.tsv` rows) at lead live, then exact-2.0 + exact-3.0
  proof legs.

- 2026-09-11 : Second beast class E0, lead bridge-1122 (spi `3eb6e8d`
  per-mob spawn contract, example1 `41c8fa1` two-mob content,
  bridge-1122 `991e004` per-mob spawn+combat dispatch, hub
  `decisions/VIRTUAL_HITBOXES.md` E0 addendum, `PORT_QUEUE`
  `TODO | e0 | TODO | TODO`) : stages 1-2 green (spi 131 ok,
  `ExampleCheck` two-mob battery, `ModelWireCheck` + `SpawnCheck`
  per-mob oracles with single-mob back-compat, forge compile +
  autoplay-compile, autoplay untouched), live proof TODO — same bar
  as every lead E0. `owned.matou` funds `my_beast` (byte-identical:
  hp 20, reach 4.0, head 2.0) plus `my_brute` (hp 30, reach 5.0,
  head 3.0, same drop+count — loot agrees, zero loot-wire change) ;
  entity mob-id NBT-persisted, per-mob cap veto / hp tripwire /
  reach dispatch on the lead. Siblings oracle-backported only
  (1710 `aabc70c`, 1165 `16dcfcc`, 1201 `8bdf576` — oracles read
  per-mob, seals stay single-mob, sole-view multi refusal pinned as
  the dispatch-port rationale), E0 green each, zero forge dispatch.
  Live blocked loud, not silent: second entity registration
  (`Example1Mod.loadMobRef` sole view refuses 2-mob content), NBT
  narrow-map delta (~5 rows) at lead live, per-mob operator keys and
  distinct per-mob drops stay named follow-ups.

- 2026-09-11 : Combat policy live on bridge-1201 (bridge-1201
  `3712673` E0, zero live fixes, hub `decisions/VIRTUAL_HITBOXES.md`
  port addendum, `PORT_QUEUE` `live | live | live | live`) : 150 s
  Forge 47.2.0 server green (`combat wired <{head=2.0}> reach
  <4.0>`, bind clean, world == pure union 1922, hook dormant, zero
  `E_HIT`) ; headless direct-client `SPAWN=1 COMBAT=1` (exit 0) —
  combat resolved head 2.0 at worldTick 500, exact-2.0 wound (18.0,
  elapsed 1), kill 1000 → carrier same tick → polled 1001 (elapsed
  1, chain intact), clean shutdown, client save world == pure union
  (1274 cells), zero `E_*` / linkage (the single `Caused by` is the
  known vanilla flite narrator `UnsatisfiedLinkError`, non-fatal).
  Four ports live, 0 `TODO` remaining, never silent.
- 2026-09-11 : Combat policy live on bridge-1165 (bridge-1165
  `17d41a8` E0, zero live fixes, hub `decisions/VIRTUAL_HITBOXES.md`
  port addendum, `PORT_QUEUE` `live | live | live | TODO`) : 150 s
  Forge 36.2.42 server green (`combat wired <{head=2.0}> reach
  <4.0>`, bind clean, world == pure union 1922, hook dormant, zero
  `E_HIT`) ; headless direct-client `SPAWN=1 COMBAT=1` (exit 0) —
  combat resolved head 2.0 at worldTick 500, exact-2.0 wound (18.0,
  elapsed 1), kill 1000 → carrier same tick → polled 1001 (elapsed
  1, chain intact), clean shutdown, client save world == pure union
  (1274 cells), zero `E_*` / linkage / `Caused by` (one benign
  `ModelBakery` missing gem-model WARN plus one benign vanilla
  Narrator `fliteWrapper` ERROR, both non-fatal). Three ports live,
  1201 remains, never silent.
- 2026-09-11 : Combat policy live on bridge-1710 (bridge-1710
  `2b74075` E0, zero live fixes, hub `decisions/VIRTUAL_HITBOXES.md`
  port addendum, `PORT_QUEUE` `live | live | TODO | TODO`) : 150 s
  Forge 1614 server green (`combat wired <{head=2.0}> reach <4.0>`,
  bind clean, world == pure union 1922, hook dormant, zero `E_HIT`) ;
  headless direct-client `SPAWN=1 COMBAT=1` (exit 0) — combat resolved
  head 2.0 at worldTick 500, exact-2.0 wound (18.0, elapsed 1), kill
  1000 → carrier 999 → polled 1001 (elapsed 1, chain intact), clean
  shutdown at 4600 ticks, client save world == pure union (1274
  cells), zero `E_*` / linkage (one benign Forge Version Check
  `Caused by` offline plus one benign missing gem-icon texture
  error, both non-fatal). The exact-2.0 proof now reads through
  sealed content on the second runtime. Two ports TODO, never
  silent.
- 2026-09-11 : Combat policy live on bridge-1122 (bridge-1122
  `c1378a1` E0, zero live fixes, hub `decisions/VIRTUAL_HITBOXES.md`
  live addendum, `PORT_QUEUE` `TODO | live | TODO | TODO`) : 150 s
  Forge 2860 server green (`combat wired <{head=2.0}> reach <4.0>`,
  bind clean, world == pure union 1922, hook dormant, zero `E_HIT`) ;
  headless direct-client `SPAWN=1 COMBAT=1` (exit 0) — combat resolved
  head 2.0 at worldTick 500, exact-2.0 wound (18.0, elapsed 1), kill
  1000 → carrier → polled 1001 (elapsed 1, chain intact), clean
  shutdown at 4600 ticks, client save world == pure union (1274
  cells), zero `E_*` / linkage (two benign client model-bake
  `Caused by` for the gem item model, non-fatal). The exact-2.0 proof
  now reads through sealed content, not constants. Three ports TODO,
  never silent.
- 2026-09-11 : Combat policy E0 on bridge-1122 (spi `0e1305b`
  SYNTAX-V5 + combat contract, example1 `fadee60` combat table,
  bridge-1122 `c1378a1` wireCombat, hub `decisions/VIRTUAL_HITBOXES.md`
  policy addendum, `PORT_QUEUE` `TODO | e0 | TODO | TODO`) : stages
  1-2 green (22 goldens py+java, `ExampleCheck` refusal battery,
  `ModelWireCheck` sealed 2x, forge compile + autoplay-compile),
  live proof TODO. `COMBAT_REACH`/`WEAKSPOTS` retired with zero
  behaviour change (content seals `reach = 4.0`, `head` 2x) ;
  mechanical SPI re-pin on the three siblings (additive, E0 green
  each). Trouvaille (spec debt): hub `SYNTAX_V1_V2_V3.md` never
  recorded the landed V4 — two-line pointer added for V4+V5 in the
  same commit, deltas stay in `spi/spec/`.
- 2026-09-11 : Combat weakspot hook live on bridge-1201
  (bridge-1201 `198e83e` E0 + `a194310` pin-loop refactor, hub
  `decisions/VIRTUAL_HITBOXES.md` live addendum, `PORT_QUEUE`
  `live | live | live | live`) : 150 s Forge 47.2.0 server green
  with the 54-line map (bind clean, world == pure union 1922, hook
  dormant, zero `E_HIT`) ; headless direct-client `SPAWN=1 COMBAT=1`
  (exit 0) — `[MatouBridge] combat resolved <bone=head mult=2.0
  dmg=1.0->2.0>`, autoplay struck head hp 20.0 at worldTick 500 then
  exact-2.0 wound (18.0, elapsed 1), kill 1000 → carrier → polled 1001
  (elapsed 1, chain intact), client save world == pure union (1274
  cells), zero `E_*` / linkage (one benign vanilla flite
  `UnsatisfiedLinkError`, same as the 1201 renderer proof). Zero live
  fixes — the owner-discipline fix landed upfront in the E0, the
  `NoSuchMethodError` class never fired. Trouvaille (hub tooling):
  combat E0 pushed `bridge-1201/tools/run-live.sh` to 452 eSLOC,
  tripping the hardened shell ceiling — fixed same-day table-driven
  (447, no logic change). Combat hook live on 4/4 runtimes.
- 2026-09-11 : Combat weakspot hook live on bridge-1165
  (bridge-1165 `531799c` E0 + `605b623` owner-discipline fix, hub
  `decisions/VIRTUAL_HITBOXES.md` live addendum, `PORT_QUEUE`
  `live | live | live | TODO`) : 150 s Forge 36.2.42 server green
  with the 54-line map (bind clean, world == pure union 1922, hook
  dormant, zero `E_HIT`) ; headless direct-client `SPAWN=1 COMBAT=1`
  (exit 0) — `[MatouBridge] combat resolved <bone=head mult=2.0
  dmg=1.0->2.0>` at worldTick 500, autoplay exact-2.0 wound (20.0 →
  18.0, elapsed 1), kill 1000 → carrier → polled 1001 (elapsed 1,
  chain intact), client save world == pure union (1274 cells), zero
  `E_*` / linkage. Trouvaille: `hitBoxes` called `getPosX/Y/Z` on
  the `MatouEntity`-typed `this` (`NoSuchMethodError` first play run
  — same owner-discipline class as the 1122 `posX` trap, fixed
  through declaring `Entity`, crash-fast killed it in seconds).
  1201 port stays the last TODO cell, never silent.
- 2026-09-11 : Combat weakspot hook E0 on bridge-1165
  (bridge-1165 `531799c`, hub `decisions/VIRTUAL_HITBOXES.md` E0
  addendum + era-1.16 derive 48→54, `PORT_QUEUE`
  `live | live | e0 | TODO`) : stages 1-2 green (forge-stub +
  autoplay-compile), live proof TODO — same 11-file shape as the 1122
  lead E0, 36.2.42-native throughout (declaring-`Entity` eye/look/pos,
  `Vector3d` components, `OVERWORLD` dim gate, `PlayerEntity` strike +
  `LivingEntity` health poll in the autoplay leg) ; the 6 new narrow-map
  rows derive clean with the first 48 byte-identical. 1201 port stays
  the last TODO cell, never silent.
- 2026-09-11 : VIRTUAL_HITBOXES promoted prototype → standard (hub
  `decisions/VIRTUAL_HITBOXES.md` : front-matter flip, 1710 live
  addendum, `PORT_QUEUE` `live | live | TODO | TODO`) : server
  weakspot hook live-proven version-native on 2/2 runtimes so far
  (1122 Forge 2860 + 1710 Forge 1614 — identical proof shape both
  sides : head x2, exact-2.0 wound elapsed 1, chain intact, unions
  pure, zero `E_*` / linkage, all gates green), known limits with
  named reopeners (BUG-042 reach override, client prediction +
  packet, attribute reach, content weakspots). 1165/1201 ports stay
  TODO cells, never silent.
- 2026-09-11 : Combat weakspot hook live on bridge-1710
  (bridge-1710 `722097b`, hub `decisions/VIRTUAL_HITBOXES.md` port
  addendum) : 150 s Forge 1614 server green (bind clean, world ==
  pure union 1922, hook dormant, zero `E_HIT`) ; headless
  direct-client `SPAWN=1 COMBAT=1` (exit 0) — `[MatouBridge] combat
  resolved <bone=head mult=2.0 dmg=1.0->2.0>` at worldTick 500,
  autoplay exact-2.0 wound (20.0 → 18.0, elapsed 1), kill 1000 →
  carrier 1001, clean shutdown at 4600 ticks, client save world ==
  pure union (1274 cells). 1614-native: public-field events
  (`entityLiving`/`source`/`ammount`), `DamageSource.getEntity`,
  `Vec3.xCoord` (see decision). Trouvaille (hub tooling):
  crash-fast watcher false-positived on the 1.7.10 splash banner
  (fixed `1f305b3` — trips on `#@!@# Game crashed!`, never the bare
  header).
  (bridge-1122 `9ae00d4` E0 + `840507c` owner-discipline fix, hub
  `decisions/VIRTUAL_HITBOXES.md` live addendum, `PORT_QUEUE`
  `TODO | live | TODO | TODO`) : server re-proof green with the
  48-line map (bind clean, world == pure union 1922, hook dormant,
  zero `E_HIT`) ; headless direct-client `SPAWN=1 COMBAT=1` run
  (exit 0) — `[MatouBridge] combat resolved <bone=head mult=2.0
  dmg=1.0->2.0>` at worldTick 500, autoplay exact-2.0 wound
  (20.0 → 18.0, elapsed 1), spawn chain intact (kill 1000 →
  carrier 1001), client save world == pure union (1274 cells),
  zero `E_*` / linkage. Trouvaille: `MatouEntity.hitBoxes` bare
  `posX` died `NoSuchFieldError` live (subclass-owner ref passes
  reobf silently — fixed through declaring `Entity`, same class
  the `E_MAP_COVER` scan cannot catch by construction).

> **Archives historiques :**
> - 2026-09-09 (fondation, syntaxe S1-S4, scaffolding 4 bridges, v1.1.0) : [docs/archive/STATE_2026_09_09.md](docs/archive/STATE_2026_09_09.md)
> - 2026-09-10 (parité 4 bridges : blocs, veines, loot, spawn, entités, repop, T4 lead) : [docs/archive/STATE_2026_09_10.md](docs/archive/STATE_2026_09_10.md)

- 2026-09-11 : Shell eSLOC ceiling hardened advisory → gate failure
  (hub `tools/check_sloc.py` + `tools/check.sh`, addenda in
  `decisions/LIVE_SHELL_COMMON.md` + `decisions/EFFECTIVE_SLOC.md`,
  `AGENTS.md` §3 amended) : full scan exits 1 with
  `FAIL (sloc-ceiling ...)` on any `*.sh` >= 450 eSLOC (was `alert`,
  exit 0) ; `check.sh` runs verdict-only `--check-ceiling` after
  `--self-test`, so hub CI refuses an over-ceiling shell anywhere in
  the org. Java `*` flags stay advisory (5 files over today —
  hardening those is its own named re-opener, not smuggled in).
  Margins at hardening: 0 over, nearest `bridge-1201/tools/run-live.sh`
  442 (8 under). `check.sh` green.

- 2026-09-11 : Decision maturity promotion to standard (hub `decisions/`) :
  - 2 decisions promoted from `prototype` to `standard`:
    `MATOU_MODEL.md` and `GL_INSTANCING_ADAPTER.md`.
  - Quality justification: both systems live-proven version-native on
    4/4 Forge runtimes (1710/1122 LWJGL2, 1165/1201 LWJGL3 — `ready
    mesh=72 verts stride=8`, `drew instances=4`, `E_GL_DRAW` silent,
    zero `E_*` / linkage, world == pure union on both legs) with 0
    shells and 0 local codes on all bridges, all gates green.
  - `MATOU_MODEL.md` "What remains" item 1 closed (consumer live x4),
    items 2-3 stay named reopeners ; `GL_INSTANCING_ADAPTER.md` gains
    "What would re-open it" (V2 sampling, proof-standard, fifth
    runtime).
  - `DECISIONS_INDEX_AND_STATUS.md` regenerated via `tools/check.sh
    --fix` ; `check.sh` passes green.

- 2026-09-11 : Beast model + GL renderer port live on bridge-1201
  (hub `decisions/MATOU_MODEL.md` + `GL_INSTANCING_ADAPTER.md`
  addenda, bridge-1201 `8d7b0d8` E0, zero live fixes, host Temurin
  17.0.20) : server green with the 48-line narrow map (bind clean,
  ticks clean, world == pure union 1922 cells, my_ore + my_gem
  registered — first live run on the thin wrapper + shared derive
  lib) ; launcher-free headless client (`run-client-direct.sh`,
  `SPAWN=1`, Xvfb, exit 0) — `[MatouRenderer] ready mesh=72 verts
  stride=8` (the SPI bake on the second LWJGL3 `Lwjgl3Backend`,
  `program=15`), `[MatouRenderer] drew instances=4` (`E_GL_DRAW`
  silent), zero `E_*` / linkage, spawn proof alongside (census 1→4
  at worldTicks 2..5, kill at 1000, gem drop at 1001 elapsed 1),
  `verify-client-save.sh` world == pure union (1274 cells, stone).
  1201-native: static `getInstance` / ClientLevel-typed `level` /
  Entity-typed `getCameraEntity` / `PoseStack.last/pose` matrices
  (JOML direct) / `EntityGetter.getEntitiesOfClass` iteration /
  `RenderLevelStageEvent` on `AFTER_ENTITIES` / quickplay join /
  installer client-extra game jar. Trouvailles: 180 s probe timed
  out on budget only (game alive rendering, full 600 s run exited
  0) ; vanilla `GlDebug` glDrawElements spam under swrast from the
  tick-1000 drop legs (~50 s after our draw, tripwire silent) +
  vanilla flite narrator `UnsatisfiedLinkError` (non-fatal).
  `PORT_QUEUE` flips both rows 1201 to `live` (live x4 everywhere,
  0 `e0` remaining).

- 2026-09-11 : Beast model + GL renderer port live on bridge-1165
  (hub `decisions/MATOU_MODEL.md` + `GL_INSTANCING_ADAPTER.md`
  addenda, bridge-1165 `628f849` + `c6e15b7`, host OpenJDK 1.8.0_502) :
  server green with the 48-line narrow map (12 renderer rows, client-jar
  javap leg, `E_MAP_COVER` extended to `com/mojang/` — bind clean, ticks
  clean, world == pure union 1922 cells, my_ore + stone, geo
  byte-identical `6577bfaf`, zero `E_MODEL_*`) ; launcher-free headless
  client (`run-client-direct.sh`, `SPAWN=1`, Xvfb/llvmpipe, exit 0) —
  `[MatouRenderer] ready mesh=72 verts` (the SPI bake on the first
  LWJGL3 `Lwjgl3Backend`, `program=12`), `[MatouRenderer] drew
  instances=4` (`E_GL_DRAW` silent), zero `E_*` / linkage, spawn proof
  alongside, verdict world == pure union (1274 cells, stone).
  1165-native: `getInstance` / ClientWorld-typed `world` /
  `getRenderViewEntity` method (Entity — no 1710 trap) /
  `getAllEntities` Iterable (no `loadedEntityList`) / event-fed
  matrices via `Matrix4f.write` (no `glGetFloat`) ; single-Minecraft
  stub merged, `autoplay/stub` deleted. Trouvailles: `com/` stub leak
  (fake MatrixStack shipped, overlay NPE — both strips fixed, the hub
  one in `run-client.sh`) + recalled `glUniformMatrix4` (LWJGL 3.2.2
  wants `glUniformMatrix4fv`, full `*C` surface javap-verified) ;
  crash-fast killed both live failures in seconds.
  `PORT_QUEUE` flips both rows 1165 to `live` (`live | live | live |
  TODO` and `live | live | live | shell`).

- 2026-09-11 : Beast model + GL renderer port live on bridge-1710
  (hub `decisions/MATOU_MODEL.md` + `GL_INSTANCING_ADAPTER.md`
  addenda, bridge-1710 `f3ef9f6` + `41c3c33`, host OpenJDK 1.8.0_502) :
  server green first try with 8 renderer SRG pins (bind clean, ticks
  clean, world == pure union 1922 cells, ids 1,165 — same T4 union,
  geo byte-identical, zero `E_MODEL_*`) ; launcher-free headless
  client (`run-client-direct.sh`, `SPAWN=1`, Xvfb/llvmpipe, exit 0) —
  `[MatouRenderer] ready mesh=72 verts` (the SPI bake, `program=3`),
  `[MatouRenderer] drew instances=4` (`E_GL_DRAW` silent), zero `E_*` /
  linkage, spawn proof alongside, verdict world == pure union (1274
  cells). 1614-native: `theWorld` / `renderViewEntity` /
  `partialTicks` FIELDS, single-Minecraft stub merged, `autoplay/stub`
  deleted. Trouvaille: `renderViewEntity` is EntityLivingBase-typed
  (`bao.i` is `sv`, javap-measured — one 600 s timeout, renderer casts
  to Entity). `PORT_QUEUE` flips both rows 1710 to `live` (`live |
  live | TODO | TODO` and `live | live | shell | shell`).

- 2026-09-11 : Beast model client-visual live on bridge-1122
  (hub `decisions/MATOU_MODEL.md` + `GL_INSTANCING_ADAPTER.md`
  addenda, bridge-1122 `34ed5b6`..`6988515`, host OpenJDK 1.8.0_502) :
  launcher-free headless client (`run-client-direct.sh`, `SPAWN=1`,
  Xvfb/llvmpipe, exit 0) — `[MatouRenderer] ready mesh=72 verts`
  (the SPI bake), `[MatouRenderer] drew instances=4` (GL accepted,
  `E_GL_DRAW` silent), zero `E_*` / linkage errors, spawn proof
  alongside, `verify-client-save.sh` world == pure union (1274 cells).
  Server re-proof green with the 42-line narrow map (1922 cells, same
  T4 union). `PORT_QUEUE` flips `Beast model` to `TODO | live | TODO
  | TODO` and `GL Instancing Renderer` to `shell | live | shell |
  shell`. Tranche findings: companion unbuildable since the item
  tranche (now `ok (autoplay-compile)` in `check.sh`), live map
  covered server refs only (now 42 lines + `E_MAP_COVER` constant-pool
  scan), Prism automation re-refused (wizard + account stall —
  protocol corrected to the direct path).

- 2026-09-11 : Beast model server no-regression live on bridge-1122
  (hub `decisions/MATOU_MODEL.md` addendum, bridge-1122 `393c020`) :
  150 s Forge 2860 run, bind clean, world == pure union (1922 cells,
  ids 1,253 — the exact T4 union) ; `my_beast.geo.json` deployed
  byte-identical beside packs.cfg, zero `E_MODEL_*` server-side, step
  6 refusal grep now trips on `E_MODEL` ; `PORT_QUEUE` stays
  `TODO | e0 | TODO | TODO` (client-visual half still TODO, GL
  precedent).

- 2026-09-11 : Beast model consumer live on bridge-1122 e0 (hub
  `decisions/MATOU_MODEL.md` addendum, spi `e52c0d3`, bridge-1122
  `3fe9c6c`) :
  - `spi`: `MatouModel.placedBoxes` world-space derivation (offset
    after px-to-block narrowing, `E_MODEL_PLACE:nan`), `ModelCheck`
    extended ; `tools/check.sh` green.
  - `bridge-1122`: `BeastModel` holder (zero MC, lazy singleton over
    `config/matoubridge/my_beast.geo.json`, cached bake, `boxesAt`,
    beast-local head-2x table, `E_MODEL_GEO:*` refusals) ;
    `MatouEntity implements Hittable` (boxes ride the feet origin) ;
    `InstancedMeshRenderer` VBO is the SPI bake (`BOX_VERTICES`
    deleted, count/stride derived) ; gate `ModelWireCheck` proves the
    shipped asset end to end pure ; live/client harness deploys the
    geo beside packs.cfg (dist SHA-pinned, keep-or-stage on client).
  - `PORT_QUEUE` row `Beast model mesh+hitboxes` (`TODO | e0 | TODO |
    TODO`) ; `tools/check-bridges.sh` green (no new forge file, no new
    `E_FORGE_*` code).
- 2026-09-11 : Declarative Bedrock model landed in SPI (hub
  `decisions/MATOU_MODEL.md` spec, spi `4831e5d`) :
  - `spi`: `fr.iamacat.spi.model` pure Java 8, zero dep (minimal
    `JsonParser`, `ModelCube`/`ModelBone`/`MatouModel`,
    `MatouModelParser` frozen Blockbench subset) ; single derivation
    point : `bakeMesh` emits 36 stride-8 vertices per cube (pos block
    units px/16, box-anchored UVs, outward CCW normals mirroring the
    live box) for the renderer VBO, `boneBoxes` derives one bind-pose
    union `BoneBox` per non-empty bone for `HitTester`.
  - Test suite `ModelCheck` covers parse goldens, bake fidelity,
    cross-product winding comparateur (24/24 triangles outward),
    bone resolution (front ray -> body, high ray -> head) and the
    `E_MODEL_*` refusal battery.
  - Mechanical SPI pin bump across all 4 bridges (to `4831e5d`) ;
    `tools/check-bridges.sh` green with 0 shells and 0 gap.
- 2026-09-11 : Decision maturity promotion to standard (hub `decisions/`) :
  - 8 decisions promoted from `prototype` to `standard`: `ITEM_REGISTRATION.md`, `REGISTRATION.md`, `LOOT.md`, `SPAWN.md`, `VEIN_V4.md`, `SPI_STATE_VOCABULARY.md`, `STRUCTURES_CROSS_FILE.md`, and `REPOP_SPIKE.md`.
  - Quality justification: every promoted system has live-proven consumers across 4/4 Forge runtimes (1.7.10, 1.12.2, 1.16.5, 1.20.1) with 0 shells and all gates 100% green.
  - `DECISIONS_INDEX_AND_STATUS.md` regenerated via `tools/check.sh --fix` ; `check.sh` passes 100% green.
- 2026-09-11 : GL Instancing adapter live driver on bridge-1122 + parity shells (hub, bridge-1122, bridge-1710, bridge-1165, bridge-1201) :
  - `bridge-1122`: `Lwjgl2Backend` implements pure `GlBackend` (LWJGL 2 GL11, GL15, GL20, GL30, GL31, GL33) ;
    `InstancedMeshRenderer` client renderer (@SideOnly) compiles GLSL 3.30 shaders, sets up static box mesh VBO and dynamic instance VBO,
    subscribes to `RenderWorldLastEvent`, packs visible `MatouEntity` (`my_beast`) instances with `InstanceFormat.pack`, and flushes instanced draw ;
    live server proof clean (30s, bind clean, ticks clean, world == pure union 1922 cells).
  - `bridge-1710`, `bridge-1165`, `bridge-1201`: parity shells for `Lwjgl2Backend.java` and `InstancedMeshRenderer.java` pointing at `decisions/GL_INSTANCING_ADAPTER.md` (`E_GL_SHELL:unwired`).
  - `decisions/GL_INSTANCING_ADAPTER.md` updated with `E_GL_SHELL:unwired` ; `decisions/BRIDGE_PARITY.md` `PORT_QUEUE` updated with `GL Instancing Renderer` row (`shell | e0 | shell | shell`) ; all gates 100% green.
- 2026-09-11 : T4 PolicyPack live-proven on Forge 2860 (bridge-1122
  `326dc1d` E0, zero fix — green first try, host OpenJDK 1.8.0_502) :
  second boot of the policy path. Server `run-live.sh` 150s
  structured+owned+vein, bind clean (no `E_EXAMPLE_POLICY:unwired`
  at `wireLoot`), world == pure union (1922 cells, ids 1,253 — same
  count as the 1614 proof : same content, second runtime).
  `LOOT=1` / `SPAWN=1` direct client legs on structured ore-wire
  packs : harvest at worldTick 1000 → bridge tick 999 → carrier the
  same tick → polled at 1001 (elapsed 1), beast kill at 1005 →
  carrier elapsed 1 ; census 1→4 at worldTicks 2..5, `spawn hp
  <20.0>`, natural adopted with sweep + replacement at 69, companion
  kill at worldTick 1000 → bridge tick 999, diamond carrier the same
  tick, polled at 1001 (elapsed 1, immediate), replacement landed at
  999 (spawn-to-loot chain through the served tables) ; both unions
  1274 cells, zero `E_*` refusals. Same tranche retires the SPAWN.md
  `SideOnly` re-opener (stub now mirrors the pinned 2860 bytes,
  RUNTIME + TYPE/FIELD/METHOD/CONSTRUCTOR javap-measured, same
  `javap -v` block lock in `run-live.sh` — green in this proof).
  `PORT_QUEUE` T4 row live on 1122 (second runtime).
- 2026-09-11 : T4 PolicyPack live-proven on Forge 36.2.42 (bridge-1165
  `77296c1` E0, zero fix — green first try, host OpenJDK 1.8.0_502) :
  third boot of the policy path. Server `run-live.sh` 150s
  structured+owned+vein, bind clean, world == pure union (1922 cells,
  ore + stone names — no numeric ids on 1.16.5). `LOOT=1` / `SPAWN=1`
  direct client legs on structured ore-wire packs : harvest at
  worldTick 1000 → carrier the same bridge tick → polled at 1001
  (elapsed 1), beast kill at 1005 → carrier elapsed 1 ; 4 landings at
  ticks 0..3 (census 1→4 at worldTicks 1..4, cap), `spawn hp <20.0>`
  at worldTick 1, natural adopted with sweep + replacement at 69,
  companion kill at worldTick 1000 → diamond carrier the same bridge
  tick, polled at 1001 (elapsed 1, immediate), replacement landed at
  1000 (spawn-to-loot chain through the served tables) ; both unions
  1274 cells, zero `E_*` refusals. No stub change in the tranche
  (the `OnlyIn` side-strip stub already carries RUNTIME retention,
  live-locked). `PORT_QUEUE` T4 row live on 1165 (third runtime).
- 2026-09-11 : T4 PolicyPack live-proven on Forge 47.2.0 (bridge-1201
  `b15eaf2` E0, zero fix — green first try, host Temurin 17.0.20
  extracted from the `matou-live-1201` image to machine-local
  `/tmp/jdk17`, never committed) : fourth boot of the policy path.
  Server `run-live.sh` 150s structured+owned+vein in docker
  (D3_OFFLINE, warm cache), bind clean, world == pure union (1922
  cells, ore + stone names — no numeric ids on 1.20.1). `LOOT=1` /
  `SPAWN=1` direct client legs on structured ore-wire packs : harvest
  at worldTick 1000 → carrier the same bridge tick → polled at 1001
  (elapsed 1), beast kill at 1005 → carrier elapsed 1 ; 4 landings at
  ticks 0..3 (census 1→4 at worldTicks 1..4, cap), `spawn hp <20.0>`
  at worldTick 1, fallen beast paid through loot with same-tick
  replacement at 73, companion kill at worldTick 1000 → diamond
  carrier the same bridge tick, polled at 1001 (elapsed 1,
  immediate), replacement landed at 1000 (spawn-to-loot chain through
  the served tables) ; both unions 1274 cells, zero `E_*` refusals.
  No stub change in the tranche (no side-stripped annotation stub on
  1.20.1 — nested dist-filtered renderer subscriber, live-proven).
   `PORT_QUEUE` T4 row live x4 (fourth runtime), vocabulary row
   already live.
- 2026-09-11 : ExamplePack policy-holder extraction (example1
  `b1f1428`, amendment in `decisions/SPI_STATE_VOCABULARY.md`) :
  sealed loot/spawn tables + twelve `PolicyPack` accessors out of
  `ExamplePack` (637 → 606 lines, new 121-line `ExamplePolicy`
  holder, pack delegates, holders carried by reference) ; E0 green
  everywhere (`ExampleCheck` unmodified, 4 bridge gates green
  unmodified, parity untouched, no re-pin, no live re-proof —
- 2026-09-11 : ExamplePack 450-line alert closed (example1
  `dc26617`, amendment in `decisions/SPI_STATE_VOCABULARY.md`) :
  `ExamplePack` narrowed 606 → 341 lines (canonical constructor
  delegation, compact `fromFiles` overloads, inline `PolicyPack` accessors) ;
  E0 green everywhere (`ExampleCheck` unmodified, 4 bridge gates green
  unmodified, parity untouched, no re-pin, no live re-proof — public
  API, sealed values and `E_*` codes unchanged). The 450-line design alert
  is closed.
- 2026-09-11 : effective SLOC standard adopted from CatzEngineNext
  (`decisions/EFFECTIVE_SLOC.md`, tool `tools/check_sloc.py`, `AGENTS.md`
  §3 amended) : blank lines and comments never count against design alerts ;
  `code_part` + `effective_sloc` state machine with 6 self-test cases wired
  into `tools/check.sh` ; `ExamplePack` sits at 297 eSLOC (341 raw).
- 2026-09-11 : item registration tranche live-proven on Forge 1614
  (example1 `26fb206` ItemSpec pure + unit tests, hub `729d7c4`
  `decisions/ITEM_REGISTRATION.md` spec + PORT_QUEUE row, shells in
  1122 `3508d4b` / 1165 `4e3fb09` / 1201 `9e9def3`, bridge-1710 `d436185`
  MatouItem + preInit GameRegistry + loot drop resolution, host OpenJDK
  1.8.0_502) : second @Mod `example1` preInit-registers `example1:my_gem`
  from `owned.matou` (stack 64, label "shiny"), init verifies
  `registered-item <example1:my_gem> id 4096` dynamic from the boot log ;
  `wireLoot` resolves drop items through `GameRegistry` instead of
  `Items.diamond` placeholder (`E_LOOT_ITEM:unknown <item>` tripwire) ;
  `dropCarrier` drops the registered item stack ; server run-live.sh
  bind clean, ticks clean, world == pure union (1922 cells, ids 1,165).
  Companion autoplay updated to poll `example1:my_gem`. Two tooling fixes:
- 2026-09-11 : item registration tranche ported and live-proven across
  the 3 sibling bridges (bridge-1122 `b1e8bdd`, bridge-1165 `2d5bdd6`,
  bridge-1201 `b3be749`) :
  - `bridge-1122`: native `RegistryEvent.Register<Item>` on mod event bus,
    `MatouItem(shortName, stackSize)` with unlocalized name and max stack size,
    `registered-item <example1:my_gem> id 4096` dynamic from boot log ;
    `wireLoot` validates drop items via `resolveItem` (`E_LOOT_ITEM:unknown <ref>`),
    `dropCarrier` drops carrier with resolved `Item` ; live server proof clean
    (60 s, world == pure union 1922 cells).
  - `bridge-1165`: native `DeferredRegister<Item>` on mod event bus,
    `MatouItem(stackSize)` via `Properties.maxStackSize`,
    `registered-item <example1:my_gem> id 976` dynamic from boot log ;
    `wireLoot` validates drop items via `resolveItem`, `dropCarrier` drops
    resolved `Item` ; live server proof clean (60 s, world == pure union 1922 cells).
  - `bridge-1201`: native `DeferredRegister<Item>` on mod event bus,
    `MatouItem(stackSize)` via `Properties.stacksTo`,
    `registered-item <example1:my_gem> id example1:my_gem` dynamic from boot log ;
    `wireLoot` validates drop items via `resolveItem`, `dropCarrier` drops
    resolved `Item` ; docker runner proof clean (150 s, world == pure union 1922 cells).
  - Autoplay companion updated across all bridges to resolve and poll `example1:my_gem`.
  - `decisions/BRIDGE_PARITY.md` `PORT_QUEUE`: Item registration row promoted
    from `live | shell | shell | shell` to `live | live | live | live` (0 shells remaining).
- 2026-09-11 : Minecraft reproducibility findings documented + virtual hitboxes
  pure geometry landed in SPI (hub `845c0f9`, spi `2e8d17b`) :
  - `decisions/MINECRAFT_BACKEND_REPRODUCIBILITY.md` ruling: documents why vanilla
    coarse AABBs, asymmetric client/server raycasts, and 4 incompatible render pipelines
    destroy cross-version reproducibility ; records lessons from `matoulib-core`
    (pure geometry vs. GL instancing) and enforces pure simulation in SPI.
  - `decisions/VIRTUAL_HITBOXES.md` spec: specifies double-precision `AABBd`, `Vec3d`,
    `BoneBox`, `RayHit`, `HitTester`, `Hittable` with Kay-Kajiya slab ray-test,
    closest bone resolution, and authoritative client/server validation.
  - `spi`: `fr.iamacat.spi.hit.*` fully implemented (pure Java 8, zero MC, zero GL) ;
    test suite `HitCheck` covers center/corner/inside hits, slab parallel rays,
    multi-bone occlusion ordering, reach cutoffs, and `E_HIT_*` error codes.
  - Mechanical SPI pin bump across all 4 bridges (bridge-1710 `9d29347`,
    bridge-1122 `5c0b797`, bridge-1165 `ce6c4d9`, bridge-1201 `0d21260` to
    `2e8d17b`) ; `tools/check-bridges.sh` green with 0 shells and 0 gap.
- 2026-09-11 : GL Instancing Adapter two-tier spec + GlBackend pure contract
  landed in SPI (hub `f4570e6`, spi `9c438e5`) :
  - `decisions/GL_INSTANCING_ADAPTER.md` spec: specifies two-tier cross-version
    architecture (pure planning/contracts in SPI, thin LWJGL2 vs LWJGL3 drivers in
    bridges, Core Profile 3.1+ compatible).
  - `spi`: `fr.iamacat.spi.render.GlBackend` pure interface (zero LWJGL, zero MC,
    Java 8) + `InstanceFormat` (12-float packed layout with NaN/overflow guards) ;
    test suite `GlBackendCheck` green (packing fidelity, mock backend workflow).
  - Mechanical SPI pin bump across all 4 bridges (bridge-1710 `856d2c6`,
    bridge-1122 `865e890`, bridge-1165 `d128dae`, bridge-1201 `320b43f` to
    `9c438e5`) ; `tools/check-bridges.sh` green with 0 shells and 0 gap.
<!-- GENERATED:phases ROADMAP.md -> STATE.md | do not hand-edit | tools/check.sh --fix -->
- F0 fondation : done 2026-09-09
- F1 hub : done 2026-09-09
- S1 syntaxe : done 2026-09-09
- S2 java port : done 2026-09-09
- M1 skeleton : done 2026-09-09
- M2 example1 : done 2026-09-09
- M3 minimap : done 2026-09-09
- B1 forge-reel : done 2026-09-09
- B2 contenu-wire : done 2026-09-09
- B3 preuve-live : done 2026-09-09
- R1 live-repro : done 2026-09-09
- R2 release-eng : done 2026-09-09
- R3 hygiene : done 2026-09-09
- S3 syntax-v2 : done 2026-09-09
- S4 syntax-v3 : done 2026-09-09
- B4 structures-wire : done 2026-09-09
- B5 live-structures : done 2026-09-09
- B6 cross-file-parts : done 2026-09-09
- C1 forge-reel-1122 : done 2026-09-09
- C2 contenu-wire-1122 : done 2026-09-09
- C3 preuve-live-1122 : done 2026-09-09
- D1 forge-reel-1201 : done 2026-09-09
- D2 contenu-wire-1201 : done 2026-09-09
- D3 preuve-live-1201 : done 2026-09-09
- E1 forge-reel-1165 : done 2026-09-09
- E2 contenu-wire-1165 : done 2026-09-09
- E3 preuve-live-1165 : done 2026-09-09
- R4 release-parity : done 2026-09-09
- 28/28 phases done
<!-- END GENERATED:phases -->
