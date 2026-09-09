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
- Prochain : preuve SPI contenu (`example1`, M2).
