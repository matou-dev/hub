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
- 2026-09-09 : direct client proof 1201 IN PROGRESS (red, not green) :
  game boots but never joins — both DEV jars lack pack.mcmeta, modern
  Forge raises a "loading mods" warning screen (`Missing metadata in
  pack mod:matoubridge/matouautoplay` in the log) and waits for a click,
  quick-play never fires, run dies by timeout. Found via screenshot +
  jstack (Render thread idle in glfwWaitEventsTimeout). Verdicts so far :
  1165 green (old script), 1122 green (1274 cells), 1201 red, 1710 todo,
  1165 re-run todo (jvm Forge-first changed its launch line). Queued
  fixes for next time : (1) internal game timeout + exit check in
  `run-client-direct.sh` (fail fast with log tail, never hang to the
  outer timeout) ; (2) mute game sound headless (e.g.
  `ALSOFT_DRIVERS=null`) ; (3) stage pack.mcmeta (pack_format 15) into
  the DEV jars at `run-client.sh` staging.
- 2026-09-09 : direct client hardening landed (all 3 queued fixes) :
  `run-client-direct.sh` gains an internal `GAME_TIMEOUT` watchdog
  (default 600s, FAIL with log tail on 124, never hangs to the outer
  timeout) + `ALSOFT_DRIVERS=null` headless default (also in the
  `run-client.sh` XVFB path ; manual LAUNCH keeps real sound) ;
  `client-common.sh` gains a `PACK_FORMAT` per-version row (1201 → 15,
  others empty = stage none, never widen silently) and `run-client.sh`
  stages pack.mcmeta into both DEV jars pre-Reobf (non-class entries
  pass through, normjar keeps bytes deterministic ; 1165 jars stay
  byte-identical, still green by construction). 1201 re-proof still TODO
  (needs a live run).
- 2026-09-09 : direct client proof 1201 GREEN on Forge 47.2.0 (hub
  `450d78a` / spi `4217ada` / bridge-1201 `72a3d61` (autoplay
  companion + pins landed : ClientTick/ServerTick stub, +2 universal
  pins, tools/autoplay/) / example1 `7370fde` / minimap `2a1270f`, host
  Temurin 17.0.20) : quick-play join ~16s after boot (no "Missing
  metadata" anywhere — the pack.mcmeta fix is validated), clean
  shutdown exit 0 after ~4 min (600s watchdog never fired), world ==
  pure union (1274 cells, stone only — same count as every live proof,
  third client runtime).
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
- 2026-09-09 : direct client 1710 provision IN PROGRESS (red, not green) :
  the 1614 installer CLI has no `--installClient` (measured
  `UnrecognizedOptionException`), so `run-client-direct.sh` assembles the
  1710 runtime from pinned bytes (Forge fragment from
  `install_profile.json`, 18 libs from the B3 server provision with
  universal + ASM sha1-reverified, vanilla primary + 33 libs from the
  pinned `ed5d8789` json) ; the game never launches yet — join path
  unmeasured (no quick-play pre-1.11), the script refuses loudly after
  assembly until the companion port lands.
- 2026-09-09 : direct client 1710 companion landed (still red) :
  bridge-1710 `8d466c7` (`tools/autoplay/` + searge pins + 1.7.10
  preseed), hub searge derive arm in `run-client.sh` ; staging green
  (narrow map 3 lines filtered from the pinned srg-mcp.srg, companion
  reobf-verified to `func_` calls, `matouautoplay.jar` staged with no
  stub leak, flat world preseeded). Live run TODO (join + 4600-tick
  clock unplayed on 1.7.10).
- 2026-09-09 : direct client proof 1710 GREEN on Forge 1614 (hub
  guard-lift + bridge-1710 `e4eff69` FML-bus companion, host OpenJDK
  1.8.0_502) : join ~7s after boot via `launchIntegratedServer` (no
  quick-play pre-1.11), clean shutdown exit 0 after ~4 min (4600 server
  ticks, 600s watchdog never fired), world == pure union (1274 cells,
  stone as numeric ID 1 — same count as every live proof, fourth client
  runtime). First attempt measured the fix, not assumed : companion on
  `MinecraftForge.EVENT_BUS` (1122 shape) booted 5 mods then sat silent
  to the watchdog — 1.7.10 ticks flow on the FML bus only (the bridge
  itself registers there, B3 green).
- 2026-09-09 : dev-client staging fixed (hub) : `PRISM_DIR` defaults to
  a per-tag isolated root in `client-common.sh` (stage/verify/direct
  agree by construction, live home still refused) ; `MATOU_MODS`
  (default `example1`) DEV-builds + stages the sibling mod set,
  metadata-aware (slim copies all, FAT only stages jars with Forge
  metadata and refuses the rest loudly — minimap stages on 1710/1122,
  names its missing wrapper on 1165/1201) ; VS Code tasks drop the
  hardcoded `/tmp/matou-prism` and the stale row labels.
- 2026-09-09 : repop spike pure half green (bridge-1710 `spike/`
  : `MinedStore` bridge-owned + `RepopJob` pur + `RepopCheck` gate
  avec comparateur store-vs-job, vanilla stone, zéro registration) ;
  hook forge + preuve live nommés en suivants
  (`decisions/REPOP_SPIKE.md`).
- 2026-09-09 : fast dev loop (hub `tools/dev-loop.sh`, NOT a gate) :
  E0 pure in seconds by default (hub check + bridge check with LIVE
  cleared), `--server` / `--client` opt-in only after E0 green,
  `--offline` reuses the provision cache ; live proofs stay full-length
  and verdict-owned, the loop only decides when to pay for them
  (`decisions/DEV_LOOP.md`).
- 2026-09-09 : repop spike hook + seal (bridge-1710 `spike/` : `RepopSeal`
  pur + hook `BreakEvent` -> `MinedStore` + seal par tick dans
  `MatouBridgeMod`, delay 200, vanilla stone, SPI untouched, `E_SPIKE_*`
  only) ; live-build replica green sans boot (17/17 pins, stub compile
  avec spike linké, reobf vérifié) ; parité 4 bridges inchangée
  (`decisions/REPOP_SPIKE.md`, preuve live nommée en suivant).
- 2026-09-09 : repop spike live-proven on Forge 1614 (bridge-1710
  `74d2fad`, host OpenJDK 1.8.0_502) : `SPIKE=1` direct client run,
  simulated harvest at (8,10,8) recorded at tick 999, repopped at tick
  1199 (delay exactly 200), companion poll + y=10 anvil spot confirm
  stone back, world == pure union (1274 cells, stone as numeric ID 1).
  Three measured findings on the way: dim 0/1/-1 tick from boot (dim-0
  filter), BreakEvent ctor reads the player (null NPEs), stub final-int
  folds into prod bytes (hook read 0,0,0, caught live —
  `no-stub-const` gate). Hub searge derive gains F (field) lines.
   (`decisions/REPOP_SPIKE.md` done, registration/veins/loot/spawn open
   as spec tranches.)
- 2026-09-10 : registration tranche live-proven on Forge 1614
  (example1 `c57919f` BlockSpec pure + refusals, bridge-1710
  `fe7e9f7`/`08b77ff`/`91909e5`/`4ce48cb`/`31a9119`, shells in
  1122/1165/1201, host OpenJDK 1.8.0_502) : second @Mod `example1`
  (frozen modid) preInit-registers `example1:my_ore` from owned.matou
  physics into the generic `MatouBlock`, init binds resolve it through
  the unchanged `PackWire`/`WorldCellSink` path ; 150s 1614 run, bind
  clean, world == pure union (1274 cells, ids 1,165 — my_ore id 165
  dynamic from the boot log, zero Illegal-prefix warnings). Three
  measured findings on the way: stub-inherited refs need hierarchy-aware
  reobf (`NoSuchMethodError MatouBlock.setBlockName` — `Reobf.java`
  walks the in-jar superclass chain, declarations included) ; subclass
  fields hide same-named vanilla slots (`opaque` is SRG field_149787_q
  — physics lands in the vanilla slot, never a shadow) ; 1.7.10 FML
  re-prefixes GameRegistry names with the active container
  (`matoubridge:example1:my_ore` + warning — hence the second @Mod and
  short-name registration). Same day : repop seam re-proven
  (`SPIKE=1` direct client on the new bytes — mined tick 1000,
  repopped 1199, delay exactly 200, client union still 1274 stone).
  (`decisions/REGISTRATION.md` active, `LIVE_PROOF_MODEL.md` amended
  to per-name IDs, client verifier gains `$NUMERIC_IDS`.)
- 2026-09-10 : VEIN_V4 live-proven on Forge 1614 (spi `67863cd`
  SYNTAX-V4 + 20 goldens, example1 `fdd9704` pure `VeinPlaceJob` +
  vein pack wiring, bridge-1710 `0e947e2` live wire, host OpenJDK
  1.8.0_502) : 150s 1614 run, bind clean, world == pure union
  (1922 cells, ids 1,165 — 256 plane my_ore at y=63, 1018 stone
  structures at y=64..65, 648 vein my_ore clusters saturating the
  BASE_Y=60 band y=60..61 ; my_ore id 165 dynamic from the boot log,
  zero warnings). E0: `check_goldens.py` 20/20 py+java,
  `ExampleCheck` seal-vs-wire comparateur 40 ticks green, legacy
  packs vein-free and behaviour-identical (`ForgeContentCheck` green
  on all 4 bridges, re-pinned to `67863cd`, no live re-proof:
  decided bytes identical for syntax <= 3). Two measured notes:
  `ExamplePack` at 477 lines (alias-loop mirror factored into
  `prefixedArgs`, next job goes table-driven — no third in-place
  branch); vein band saturates 18x18x2 over 4000 ticks as predicted
  (seeded origins over GRID 16 plus 3x3 footprint).
   (`decisions/VEIN_V4.md` active.)
- 2026-09-10 : LOOT live-proven on Forge 1614 (example1 `5d5963c`
  pure `LootJob` + single-mob `LootTable`, bridge-1710 `9c74d05`/
  `3c2ea06` seam + live wire, host OpenJDK 1.8.0_502) : `LOOT=1`
  direct client run, bind clean, exit 0 after 4600 server ticks —
  companion harvests registered ore at (8,10,8) at worldTick 1000 and
  kills a spawned pig at (12,10,8) at 1005, bridge records at ticks
  999/1004 and drops one diamond carrier the same tick each, both
  polled within 1 tick (immediate, no repop delay) ; world == pure
  union (1274 cells, ids 1,165 — ore-wire legacy pack, drops are
  entities, verdict takes `NUMERIC_IDS=example1:my_ore=165`).
  E0: `ExampleCheck` loot battery green, `LootCheck`
  store-vs-job comparateur (table expansion, counts 1..2) green,
  stub compile + SRG/universal pins + companion derive green on both
  sides, no SPI change (no re-pin), parity holds over 4 bridges (no
  new forge file, `E_LOOT_*` local). Two measured notes:
  stub-owner discipline (reobf walks in-jar supers only — inherited
  vanilla members go through the declaring stub type ; first live run
  died loud `NoSuchFieldError: posX`, never silent) ; `ExamplePack`
  untouched (table wires beside it, next cell job still goes
  table-driven).
   (`decisions/LOOT.md` active.)
- 2026-09-10 : SPAWN live-proven on Forge 1614 (example1 `9fa57e1`
  pure `SpawnJob` + single-mob `SpawnTable`, bridge-1710 `ea384e9`
  seam + live wire, host OpenJDK 1.8.0_502) : `SPAWN=1` direct client
  run, bind clean, exit 0 after 4600 server ticks — 4 landings at
  ticks 0..3 (census 4 at worldTick 5, cap 4, budget 1), natural pig
  adopted at tick 49, fallen pig swept + replacement landed at 69, 48
  natural joins vetoed past cap, companion kill at worldTick 1000 →
  diamond carrier at 1001 (elapsed 1, immediate — the loot table pays
  the spawn-to-loot chain, replacement landed at 999 after the kill
  release) ; world == pure union (1274 cells, ids 1,165 — legacy
  ore-wire pack, beasts are entities, verdict takes
  `NUMERIC_IDS=example1:my_ore=165`).
  E0: `ExampleCheck` spawn battery green, `SpawnCheck`
  store-vs-job comparateur (slots == decision size, budgets 1..2)
  green, stub compile + SRG/universal pins + companion derive green on
  both sides, no SPI change (no re-pin), parity holds over 4 bridges
  (no new forge file, `E_SPAWN_*` local). Landing + veto passive
  unless `SPAWN=1`, so union and loot runs stay spawn-free by
  construction (no live re-proof of those runs: flag-gated passivity).
  Three measured notes: dead beasts linger in the loaded list
  (companion counts living only, `isDead` searge-pinned — first live
  run failed loud on a corpse past cap) ; natural spawns bypass
  `EntityJoinWorldEvent` on 1614 (second live run failed loud on a
  fifth living pig — hence the per-tick poll reconcile beside the
  event hooks) ; bridge pigs fall off the union plane (one 60-block
  fall proved death→loot→release→respawn live).
   (`decisions/SPAWN.md` active.)
- 2026-09-10 : SPAWN custom entity live-proven on Forge 1614 (bridge-1710
  `00a8ee8` `MatouEntity` + `EntityRegistry` + pig-renderer mapping,
  companion `required-after`, shells in 1122/1165/1201, host OpenJDK
  1.8.0_502) : `SPAWN=1` direct client run, bind clean, exit 0 after
  4600 server ticks — 4 landings at ticks 0..3 (census 4 at worldTick
  5, cap 4, budget 1), natural beast adopted at tick 49, swept +
  replacement landed at 69, companion kill at worldTick 1000 →
  diamond carrier at 1001 (elapsed 1, immediate — the loot table pays
  the spawn-to-loot chain on the registered beast) ; world == pure
  union (1274 cells, ids 1,165 — legacy ore-wire pack, block id stable
  across the entity registration, `NUMERIC_IDS` from the boot log).
  Two measured findings: ModClassLoader negative-cache CNFE (verifier
  eager load + file-order construction — fixed by the companion
  dependency, load-bearing) ; `RenderPig` 3-arg saddle ctor (notch
  javap from the ForgeGradle cache, never recalled).
   (`decisions/SPAWN.md` custom entity tranche.)
- 2026-09-10 : SPAWN hp tranche live-proven on Forge 1614 (example1
  `SpawnTable.hp` + refusals, bridge-1710 attribute seam +
  `E_SPAWN_HP:diverged` tripwire + companion max-health poll, host
  OpenJDK 1.8.0_502) : `SPAWN=1` direct client run, bind clean, exit 0
  after 4600 server ticks — `spawn wired <...my_beast> hp <20>`,
  `spawn hp <20.0>` at worldTick 2, census 4 at worldTick 5, kill at
  worldTick 1000 → diamond carrier at 1001 (elapsed 1, immediate) ;
  world == pure union (1274 cells, ids 1,165,
  `NUMERIC_IDS=example1:my_ore=165` from the boot log). One measured
  finding: the vanilla attribute instance is an interface —
  class-stubbed it dies loud `IncompatibleClassChangeError` at the
  first landing (stub is an interface, `invokeinterface` links).
   (`decisions/SPAWN.md` hp tranche.)
- 2026-09-10 : SPAWN content-decides tranche live-proven on Forge
  1614 (example1 `SpawnTable` cap/budget/y_min/y_max + `LootTable`
  count from the mob, bridge-1710 wires transport, 5 constants gone,
  `LOOT_ORE`/`REPOP_*`/`SPAWN` switch/diamond explicitly kept, host
  OpenJDK 1.8.0_502) : `SPAWN=1` direct client run, bind clean, exit 0
  after 4600 server ticks — `spawn wired <...my_beast> hp <20> cap
  <4> budget <1> y <66..68>`, `loot wired <{ore,beast}> count <1>`,
  census 1→4 at worldTicks 2..5, kill at worldTick 1000 → diamond
  carrier at 1001 (elapsed 1, immediate) ; world == pure union (1274
  cells, ids 1,165, `NUMERIC_IDS=example1:my_ore=165` from the boot
  log, id 165 again).
   (`decisions/SPAWN.md` content-decides tranche, `decisions/LOOT.md`
   count re-opener spent.)
- 2026-09-10 : SPAWN operator-override tranche live-proven on Forge
  1614 (bridge-1710 `OperatorPolicy` pure + wire transport, companion
  `SPAWN_CAP` env mirror, no SPI change, no new forge file, host
  OpenJDK 1.8.0_502) : `SPAWN=1` + `SPAWN_CAP=2` direct client run
  (packs.cfg = T1 wire plus `spawn.cap=2`), bind clean, exit 0 after
  4600 server ticks — `spawn wired <...my_beast> hp <20> cap <2>
  budget <1> y <66..68> overridden <cap>`, `loot wired <{ore,beast}>
  count <1> ore <[example1:my_ore]>` (`LOOT_ORE` constant gone, scope
  from the wire-block column), census 1→2 at worldTicks 2..3
  (landings stop at ticks 0,1 — same RNG pads as the cap-4 run),
  kill at worldTick 1000 → diamond carrier at 1001 (elapsed 1,
  immediate) ; world == pure union (1274 cells, ids 1,165,
  `NUMERIC_IDS=example1:my_ore=165` from the boot log, id 165 again).
    (`decisions/SPAWN.md` operator-override tranche,
    `decisions/LOOT.md` ore-scope re-opener spent.)
- 2026-09-10 : decisions tracking columns adopted from CatzEngineNext
  (2026-09-10 addendum) : front-matter gains closed `maturity`
  (prototype/standard/production/unrated) +
  `scope` (spi/bridge/content/client/hub/shared/unrated), canonical
  order type/status/maturity/scope/roadmap, gate refuses loud on drift
  ; all 25 files rated in the landing commit (specs live-proven on the
  lead bridge only = prototype, seam + syntax = standard, rulings +
  note = unrated) ; Catz `phase`/`note-present` types and
  shell/game/shared scopes deliberately not adopted
  (`decisions/DECISIONS_INDEX_AND_STATUS.md` addendum).
- 2026-09-10 : bridge parity goes gap-aware (1710 led by ~1000 forge
  lines with dims 1-3 still green : same basenames via shells, same
  `E_FORGE_*`) : `check-bridges.sh` gains dim 4 (full `E_*` catalog
  over forge+java cited in hub decisions + shells pointed at a
  decision + per-bridge gap printed — today 1710 24 local codes 0
  shells, each sibling 3 shells) ; 5 seal codes the gate caught on its
  first run now declared (`E_LOOT_STORE/WIRE`, `E_SPAWN_STORE/WIRE`,
  `E_SPIKE_MINED`) ; hand-kept PORT_QUEUE
  (`decisions/BRIDGE_PARITY.md`, 7 tranches x 4 bridges, stale pin
  fixed) ; scaffolder renders the 3 shells so a fifth bridge is
  parity-green at scaffold.
  `StateVocabulary` + `SpawnStates`/`LootStates` + `VocabularyPack`,
  example1 `94e7f9f` namespaces + delegating jobs + pack provision,
  bridge-1710 `4563380` vocabulary seals + `no-lateral-import` gate,
  4 bridges re-pinned to `0ace688`, E0 built with javac 21
  `--release 8`) : E0 green
  everywhere (`VocabularyCheck` + `ExampleCheck` provision battery +
  `SpawnCheck`/`LootCheck` comparateurs over the provision path with
  null/wrong-vocabulary refusals + key-order assertions +
  stub-compile of the exact live bytes + parity over 4 bridges). No
  live re-proof (scaling-audit precedent): sealed outputs are
  byte-identical (same ids, same values, same insertion order), every
  decided path E0-locked. The Mod keeps its four `example1` imports
  (tables + jobs + kinds — T4 pack-driven re-opener, same file).
    (`decisions/SPI_STATE_VOCABULARY.md` active.)
- 2026-09-10 : registration block-only ported off the lead bridge
  (beast stays shell, row 2 untouched) : 1122 live-proven on Forge
  2860 (bridge-1122 `49aa98a`, registry-event `Example1Mod`,
  `my_ore` id 253 dynamic, world == pure union 1274 cells ids 1,253)
  ; 1165 E0-landed (bridge-1165 `02e29a4`, `DeferredRegister`, every
  stub member `javap`-measured) ; 1201 E0-landed (bridge-1201
  `37fb977`, `DeferredRegister`, pins + bind-timing + id token flagged
  for the live tranche). Measured on the way (hub
  `decisions/REGISTRATION.md` port lessons) : no `GameRegistry`
  on 2860 (registry event instead) ; hierarchy-aware `Reobf` ports
  with any block-owning bridge ; erased descriptors for generic Forge
  calls (stub chain mirrors `Impl<Block>`) ; SRG-anchored derive rows
  for descriptor collisions. `PORT_QUEUE` gains the `e0` state
  (E0-green, live TODO).
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
