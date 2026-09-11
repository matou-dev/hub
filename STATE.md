# STATE.md — présent

> **Archives historiques :**
> - 2026-09-09 (fondation, syntaxe S1-S4, scaffolding 4 bridges, v1.1.0) : [docs/archive/STATE_2026_09_09.md](docs/archive/STATE_2026_09_09.md)
> - 2026-09-10 (parité 4 bridges : blocs, veines, loot, spawn, entités, repop, T4 lead) : [docs/archive/STATE_2026_09_10.md](docs/archive/STATE_2026_09_10.md)

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
