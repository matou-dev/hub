# matou-dev — agent entry point (SSOT org)

**Ce fichier seul gouverne le travail dans l'org.** Tout autre fichier agent
des 7 repos est un pointeur d'une ligne vers ici.

> **State : voir `STATE.md` (présent) + `ROADMAP.md` (file).** Une ligne est
> done seulement quand ses gates passent verts.
> **Ne jamais déclarer un gate vert sans l'avoir lancé.**

## 1. Repos

| Repo | Rôle | Gate |
|---|---|---|
| `matou-dev/hub` (ici) | doctrine, `NAMES.md`, `STATE`, `ROADMAP`, check partagé | `tools/check.sh` |
| `matou-dev/spi` | contrat pur, zéro MC | `zero-mc-import` |
| `matou-dev/bridge-1710` | seul traducteur MC 1.7.10, modid `matoubridge` | `no-legacy-matoulib` |
| `matou-dev/bridge-1122` | seul traducteur MC 1.12.2, modid `matoubridge` | `no-legacy-matoulib` |
| `matou-dev/bridge-1201` | seul traducteur MC 1.20.1, modid `matoubridge` | `no-legacy-matoulib` |
| `matou-dev/bridge-1165` | seul traducteur MC 1.16.5, modid `matoubridge` | `no-legacy-matoulib` |
| `matou-dev/example1` | preuve SPI contenu, zéro MC | `zero-mc-import` |
| `matou-dev/minimap` | preuve SPI client, zéro MC | `zero-mc-import` |

## 2. Début de session — lire avant d'agir

1. `git status --short && git log --oneline -5` (premier geste, sinon session
   invalide — état halluciné).
2. Lire `STATE.md` puis `ROADMAP.md` puis `NAMES.md`.
3. Règles de layering (voir `decisions/LAYER_Q1_Q11.md`, reconstruit
   depuis les gates) :
   submods = zéro import MC, seule la lib + un bridge par version touche MC.
4. Lire `decisions/DECISIONS_INDEX_AND_STATUS.md` (index : un fichier une
   ligne avec type + statut). Les décisions se pointent au lieu d'usage,
   jamais en liste exhaustive ici.

## 3. Avant d'écrire — anti-doublon obligatoire

Avant struct, fonction de conversion ou fixture : grep workspace si le concept
existe déjà sous un autre nom (un audit sans grep est invalide). Type partagé
= base commune, jamais d'import latéral. Fichier vers 450 lignes effectives
(eSLOC, hors commentaires et lignes vides — `tools/check_sloc.py`) = alerte de
conception (table-driven, fusion, suppression — jamais split satellite) ;
pour les scripts shell l'alerte est un gate dur (`tools/check.sh` refuse
tout `*.sh` >= 450 eSLOC — voir `decisions/EFFECTIVE_SLOC.md`), pour Java
elle reste une alerte.
Si du code existant — ou ce qu'on s'apprête à écrire — contredit le layering
Q1-Q11 : STOP + signaler avec preuve `file:line`, jamais d'extension
silencieuse.

## 4. Après — docs dans le même commit, commit immédiat

Un commit qui rend un doc faux sans le mettre à jour est incomplet. `NAMES.md`
suit dans le même commit que tout rename. Tout concept figé par la tranche
devient `decisions/<NOM>.md` créé ou mis à jour dans le même commit (voir
`decisions/DOCS_DEFINITION_OF_DONE.md` — un agent frais lit le fichier,
pas la conversation). Avant commit : grep l'identifiant,
la constante ou le chemin déplacé dans les `.md` et les commentaires — un doc
qui nomme ce qu'on vient de bouger ment maintenant. Norme et logique jamais
mélangées : un commit fmt/norme ne porte aucune logique. Statuts de phases : SSOT =
table `ROADMAP.md`, miroir dérivé = bloc GENERATED de `STATE.md`
(`tools/check.sh --fix` régénère, `check` refuse toute dérive — bloc jamais
édité à la main).
Unité terminée (gates verts) = commit local immédiat, un par repo touché,
avant de passer à la suivante : un travail non committé est écrasable par la
session suivante. Le push passe par `tools/autopush.sh` (dry-run par
défaut : status + ahead/behind + gate, ne touche à rien ; `--execute -m
"msg"` pousse, gate vert requis par repo sinon sauté, jamais de
`--force`, seul `main` pousse ; arbres propres avant — un arbre sale
serait committé tel quel sous `-m`).
Bridges portent `SPI_PIN` (SPI validé) ; `tools/check-bridges.sh` refuse
toute parité rompue (pins, file-set forge, catalogue `E_FORGE_*`).

## 5. Règles transversales

Docs/comments en anglais, chat en français. Commits `type(scope): what`.
Un gate non lancé ne passe pas. Questions user avec trade-off architectural :
option long-terme en premier + `(Recommended)`, workaround nommé avec sa
dette — jamais de workaround recommandé. Posture challenge-then-propose :
voir `decisions/CHALLENGE_THEN_PROPOSE.md`.

## 6. Audits — pas pour rien

Pas d'audit sans gate rouge ou métrique qui franchit un seuil. Un audit se
ferme vert, pas d'audits ouverts qui s'accumulent.
