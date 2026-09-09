# STATE.md — présent

- 2026-09-09 : fondation live. Org `matou-dev`, 4 repos scaffoldés + gates
  verts et mordants (`zero-mc-import`, `no-legacy-matoulib`).
- Hub créé, `NAMES.md` rapatrié ici (SSOT), les 4 repos pointent vers ici.
- S1 done : spec + `spi/parser/matou_parse.py` + 9 goldens, gate vert et
  mordant (un bug réel trouvé par les goldens avant freeze).
- S2 done : port Java (`java/src/fr.iamacat.spi`, bytecode 8), comparaison
  structurelle, divergence Java dénoncée nommément par le gate.
- Outil : `hub/tools/autopush.sh` (dry-run par défaut, gate vert exigé,
  jamais de force).
- M1 done : `spi` squelette Java 8 (`MatouId`, `MatouRng` adressé,
  `Snapshot` + `MatouJob` purs) + self-test gate vert ; `bridge-1710`
  walking skeleton (`SpiBridge` decide→apply pur, `TODO(FORGE)` nommé) +
  gate vert contre le sibling `../spi` ; goldens py+java toujours verts.
- M2 done : `example1` preuve contenu (`content/owned.matou` 4 owned +
  `content/additive.matou` tardif, jobs purs `OwnedVeinJob` +
  `AdditiveScatterJob` + `merge` additif, parité py/java) + gate vert et
  mordant (refus bare-ident identique des 2 parsers).
- M3 done : `minimap` preuve client (`MinimapJob` rend des lignes d'overlay
  depuis des snapshots SPI, jamais de draw ni de remplacement vanilla, void
  explicite, refus bruyants) + gate vert et mordant (golden 3x3 exact,
  vue qui suit le joueur).
- 2026-09-09 : live re-proof post hardening (hub `b730266` / spi `66cdb52`
  / bridge `0bcd2f9` / example1 `ca7e5e2` / minimap `df1383e`, host OpenJDK
  1.8.0_502) : 150s 1614 run, bind clean, world == pure union (256 cells,
  stone only).
- 2026-09-09 : live proof with structures (hub `42da93a` / spi `4af792a` /
  bridge `e2c87e0` / example1 `164f707` / minimap `df1383e`, host OpenJDK
  1.8.0_502) : 150s 1614 run, bind clean, world == pure union (1274 cells,
  stone only — 2D plane at wire y=63 plus hut composite volumes at
  y=64..65, chunks (0..1, -1..1)).
- 2026-09-09 : live re-proof after cross-file wiring (hub `3adb395` / spi
  `4af792a` / bridge `e2c87e0` / example1 `2bd9dd6` / minimap `df1383e`,
  clean B3_DIR) : 150s 1614 run, bind clean, world == pure union (1274
  cells, stone only — hut path byte-identical through the multi-file
  machinery; cross-file `ext` proven at the gate, 19 cells).
- 2026-09-09 : shared apply seam up into `matou-spi` v1.1.0
  (`fr.iamacat.bridge`, FQNs unchanged, `BridgeCheck` green in SPI) ;
  `bridge-1710` re-points (drops its 6 copies, `ForgeContentCheck`
  stays) ; `bridge-1122` repo opened (PROPOSED) against the seam,
  phases C1-C3 todo.
- 2026-09-09 : bridge-1122 arc done, live-proven on Forge 2860 (hub
  `7ae5746` covers C2, C3 harness + proof in bridge-1122 `36782d5` ;
  spi `0073226` / example1 `80e6c59` / minimap `df1383e`, host OpenJDK
  1.8.0_502) : 150s 2860 run, bind clean, world == pure union (1274
   cells, stone only — same count as the 1614 proof : same content,
   same seam, second runtime ; narrow MCP→SRG map derived in-run from
   pinned bytes, `getDimension` Forge-added passthrough).
- 2026-09-09 : release v1.1.0 (bridge-1710 `114ee19` / bridge-1122
  `cdd6baf` / spi `0073226`, `@Mod` 1.1.0 both bridges) : `BUILD_ONLY`
  drops assembled + self-verified both sides (pins, reobf, java-52,
  SHA256SUMS), tags pushed (spi/1710/1122), 3 GitHub releases (spi
  source + 2 server drops with `structure.matou`). Same round:
   `run-live.sh` 1710 seam fix (no `java/src` stage), `AGENTS.md`
   6-repo fix, GitHub descriptions set (6/6).
- 2026-09-09 : `bridge-1201` scaffolded (1.20.1/Forge 47.2.0, sink modern,
  mapping derive, ref bridge-1122, pin v1.1.0) : etages 1+2 green at
  scaffold, parity holds over 3 bridges ; phases D1-D3 opened, D3 live TODO
  (placeholder fails loud until ported from bridge-1122).
- 2026-09-09 : D3 live-proven on Forge 47.2.0 (bridge-1201 `baef65f`,
  image `matou-live-1201` temurin17, docker) : 150s 47.2.0 run, bind
  clean, world == pure union (1274 cells, stone only — same count as the
  1614/2860 proofs : same content, third runtime). D3 note (production
  model, measured via the installer MERGE_MAPPING chain, not assumed) :
  Mojmap classes + SRG members (4-line narrow map derived at D3 time from
  Mojang server.txt + mcp_config joined.tsrg v2 + javap) ; bridge ships
  FAT (spi+example1 embedded — 1.20.1 modules isolate every mods/ jar,
  NoClassDefFoundError found live) ; stub annotations mirror RUNTIME
  retention (eventbus discovers handlers through visible annotations
  only — invisible @SubscribeEvent registered nothing, silently, found
   live) ; anvil probe reads the palette format (incl. nested lists,
   single-valued sections, signed bytes).
- 2026-09-09 : `bridge-1165` scaffolded (1.16.5/Forge 36.2.42, installer
  HTTP 200 on Maven, sink modern, mapping derive, ref bridge-1122, pin
  v1.1.0) : etages 1+2 green at scaffold against the copied 1.12 stubs —
  the 1.16.5 port (event bus, LogicalSide, dimension key, BlockState,
  stubs) is the body of E1 ; phases E1-E3 opened, E3 live TODO
  (placeholder fails loud until ported).
- 2026-09-09 : E1 done (bridge-1165 `aa1fe2e`) : 1.16.5 event-bus port
  (`EVENT_BUS` constructor register, `LogicalSide`, `OVERWORLD`
  dimension key, `BlockState`, `ForgeRegistries` block resolve), 1.12
  stubs replaced by a 1.16.5 (MCP) shape-only set ; etages 1+2 green,
  parity holds over 4 bridges (same `SPI_PIN`, same forge file-set,
  same `E_FORGE_*` catalog).
- 2026-09-09 : E2 done (no bridge code change — `ForgeContentCheck`
  pure E2E green since scaffold, `PackWire.bind` 1165-native from E1,
  `packs.cfg` contract unchanged) ; etages 1+2 green, parity holds
  over 4 bridges.
- 2026-09-09 : E3 live-proven on Forge 36.2.42 (bridge-1165 `61af2a4`,
  Java 8) : 150s 36.2.42 run, bind clean, world == pure union (1274
  cells, stone only — same count as the 1614/2860/47.2.0 proofs : same
  content, fourth runtime). E3 notes (measured, not assumed) : MCP
  model like C3 (SRG runtime, MCP sources + Reobf) with a snapshot
  name lock (three same-type static RegistryKey fields — descriptor
  alone cannot pick OVERWORLD) ; FAT bridge + `mods.toml` (ModLauncher
  isolation, D3 family) ; `IForgeRegistryEntry` bound mirrored in
  stubs (erased getValue descriptor, NoSuchMethodError found live) ;
  1.16.5 anvil reads `Level.Sections`/`Palette`/`BlockStates` ; JDK8
  javap prints annotations as pool refs (pool-resolving check).
- 2026-09-09 : dev-client helpers generalized into the hub (SSOT
  `hub/tools/run-client.sh` + `verify-client-save.sh`, per-version table
  `tools/client-common.sh`, ASM pin checked against each bridge
  `run-live.sh`) ; `bridge-1165` logic replaced by thin wrappers, other
  bridges gain the same wrappers (rows experimental/untested) ;
  `scaffold-bridge.sh` copies them to future bridges. Equivalence proven
  for 1165 : generalized staging builds byte-identical jars to the moved
  script (same EPOCH, normjar-clamped).
- 2026-09-09 : launcher-free direct client proof on Forge 2860
  (bridge-1122 `8850e29` / hub `b417d64`, host OpenJDK 1.8.0_502) :
  world == pure union (1274 cells, stone as numeric ID 1 — same count
  as every live proof, second client runtime). Port lessons (measured,
  not assumed) : stop clock moved to server ticks (the client out-ticks
  a loaded same-JVM server — 967/1274 on the client clock) ;
  `pauseOnLostFocus:false` pinned at staging (Xvfb never owns the
  focus — 1 world tick played, then silence until timeout) ; legacy
  launch assembly (explicit `-cp` + split `minecraftArguments` —
  LaunchWrapper carries no classpath) ; numeric-ID verifier table
  (pre-flattening frozen IDs, same fact as the C3 verdict) ; javap
  wildcard-bounds parse fix (1.12-era `Queue<FutureTask<?>>`).
- 2026-09-09 : test-mod scaling audit closed green (no red gate, metric
  trigger: ExampleCheck 840 lines, MatouParse-adjacent codec triplication,
  positional job indexing) ; structural fix, behaviour-preserving :
  SPI `Cell` + `Counts` + typed `Snapshot` + `Packs.loadConfigured` +
  `AUTHORING.md` (spi `00934e1`), `ExampleIds` + pack `job(id)` registry
  + table-driven gate (example1 `c0778ba`), slim `MinimapJob` + r=8
  golden (minimap `77bdb0b`), 4 bridges re-pinned to `00934e1` with
  merge comparateur still green (no live re-proof: decided bytes
  identical, gates lock them).
- 2026-09-09 : automated client proof without launcher (1165) : hub
  `run-client-direct.sh` (official installer provisions once, plain java
  under xvfb, verdict owns status) green : world == pure union (1274
  cells, stone only — same count as every live proof). Same round :
  autoplay derive SRG-slot fix (Reobf maps MCP->LEFT), WorldGenSettings
  preseed (legacy generator tags ignored on 1.16.5), Qt-xcb pin under
  XVFB, game-dir CWD (the bridge reads packs.cfg relative).
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
