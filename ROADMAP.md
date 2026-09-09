# ROADMAP.md — file

| Phase | What | Status |
|---|---|---|
| F0 fondation | Org + 4 repos + gates zero-MC mordants | done 2026-09-09 |
| F1 hub | Hub doctrine + NAMES rapatrié + pointeurs | done 2026-09-09 |
| S1 syntaxe | SYNTAX-V1 gelée + parser ref + 9 goldens, gate vert | done 2026-09-09 |
| S2 java port | Port Java zero-MC, mêmes 9 goldens, divergence nommée | done 2026-09-09 |
| M1 skeleton | `spi` squelette (IDs, Job, RNG) + `bridge-1710` walking skeleton + parity gate continue | done 2026-09-09 |
| M2 example1 | Preuve SPI contenu (owned + additif) | done 2026-09-09 |
| M3 minimap | Preuve SPI client | done 2026-09-09 |
| B1 forge-reel | Bridge 1.7.10 Forge 1614 : seam pur + Mod FML passif, gate 2 étages | done 2026-09-09 |
| B2 contenu-wire | Contrat ContentPack en SPI + ExamplePack + ForgeContent + packs.cfg, E2E pur gate | done 2026-09-09 |
| B3 preuve-live | Forge 1614 live run: PackWire.bind reel + tick serveur END dim 0, owned verbatim | done 2026-09-09 |
| R1 live-repro | Live rejouable: SRG auto-discover + pins sha1, cache offline, Docker Java 8, LIVE opt-in | done 2026-09-09 |
| R2 release-eng | Tags v1 + dist versionné reproductible (BUILD_ONLY), stores restent DRAFT | done 2026-09-09 |
| R3 hygiene | Docs EN, README public, changelog, docker non-root | done 2026-09-09 |
| S3 syntax-v2 | SYNTAX-V2 i32/vec3/list + 14 goldens py+java, gate vert | done 2026-09-09 |
| S4 syntax-v3 | SYNTAX-V3 structure genre version-gated + 18 goldens py+java, ContentPack both cell shapes | done 2026-09-09 |
| B4 structures-wire | StructurePlaceJob pur + recursive parts + palette aliases + V3 volume landing, E2E pur gate | done 2026-09-09 |
| B5 live-structures | Forge 1614 live hut composite 1274 cells, verdict slice from packs.cfg | done 2026-09-09 |
| B6 cross-file-parts | fromFiles multi-fichiers + pack structureFiles/structureRoot, imports parser-enforced, live hut re-proof | done 2026-09-09 |
| C1 forge-reel-1122 | Bridge 1.12.2 Forge 2860 : seam pur + Mod FML passif, gate 2 étages | done 2026-09-09 |
| C2 contenu-wire-1122 | PackWire.bind 1122 + ForgeContent + packs.cfg, E2E pur gate | done 2026-09-09 |
| C3 preuve-live-1122 | Forge 2860 live run : bind reel + tick serveur, world == pure union | done 2026-09-09 |

Contexte décisions : Q1 cohabitation 1.7.10 passive + multi-version ouvert ;
Q2 layering strict zéro-MC submods ; Q3-Q4 bypass nos contenus (owned =
backend seul, non-owned = additif tardif) ; Q5-Q9 kernels purs prouvés seuls ;
Q6 SPI + bridge/version ; Q7-Q8 preuves client/contenu ; Q10 coût additif ;
Q11 repo disjoint ; Q-N1..N3 naming (`matou-dev`, `NAMES.md`, protocole
strict) ; Q-F1 fondation d'abord ; Q-H1 hub doctrine complète.
