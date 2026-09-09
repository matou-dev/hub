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
- 21/21 phases done
<!-- END GENERATED:phases -->
