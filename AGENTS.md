# matou-dev — agent entry point (SSOT org)

**Ce fichier seul gouverne le travail dans l'org.** Tout autre fichier agent
des 4 repos est un pointeur d'une ligne vers ici.

> **State : voir `STATE.md` (présent) + `ROADMAP.md` (file).** Une ligne est
> done seulement quand ses gates passent verts.
> **Ne jamais déclarer un gate vert sans l'avoir lancé.**

## 1. Repos

| Repo | Rôle | Gate |
|---|---|---|
| `matou-dev/hub` (ici) | doctrine, `NAMES.md`, `STATE`, `ROADMAP`, check partagé | `tools/check.sh` |
| `matou-dev/spi` | contrat pur, zéro MC | `zero-mc-import` |
| `matou-dev/bridge-1710` | seul traducteur MC 1.7.10, modid `matoubridge` | `no-legacy-matoulib` |
| `matou-dev/example1` | preuve SPI contenu, zéro MC | `zero-mc-import` |
| `matou-dev/minimap` | preuve SPI client, zéro MC | `zero-mc-import` |

## 2. Début de session — lire avant d'agir

1. `git status --short && git log --oneline -5` (premier geste, sinon session
   invalide — état halluciné).
2. Lire `STATE.md` puis `ROADMAP.md` puis `NAMES.md`.
3. Règles de layering (décisions Q1-Q11, voir `ROADMAP.md` §contexte) :
   submods = zéro import MC, seule la lib + un bridge par version touche MC.

## 3. Avant d'écrire — anti-doublon obligatoire

Avant struct, fonction de conversion ou fixture : grep workspace si le concept
existe déjà sous un autre nom (un audit sans grep est invalide). Type partagé
= base commune, jamais d'import latéral. Fichier vers 450 lignes = alerte de
conception (table-driven, fusion, suppression — jamais split satellite).

## 4. Après — docs dans le même commit, commit immédiat

Un commit qui rend un doc faux sans le mettre à jour est incomplet. `NAMES.md`
suit dans le même commit que tout rename. Dérivés `STATE.md` : tenus à la
main tant que `check --fix` n'existe pas (dette explicite, voir ROADMAP).
Unité terminée (gates verts) = commit local immédiat, un par repo touché,
avant de passer à la suivante : un travail non committé est écrasable par la
session suivante. Le push passe par `tools/autopush.sh` (`--execute`).

## 5. Règles transversales

Docs/comments en anglais, chat en français. Commits `type(scope): what`.
Un gate non lancé ne passe pas. Questions user avec trade-off architectural :
option long-terme en premier + `(Recommended)`, workaround nommé avec sa
dette — jamais de workaround recommandé.
