# NAMES.md — SSOT des identifiants (décisions Q-N1..Q-N3)

Règle : le slug GitHub n'est que de l'hébergement. Maven / modid / namespace
SPI / slugs plateformes sont gelés ici et ne suivent jamais un rename de repo.
Un slug global pris se détecte avant création (`curl
https://api.modrinth.com/v2/project/<slug>` → 404 = libre + recherche
CurseForge). Statut PROPOSED = pas encore réservé sur la plateforme.

| Repo GitHub | Maven | Modid FML | Namespace SPI | Modrinth | CurseForge | Statut |
|---|---|---|---|---|---|---|
| `matou-dev/spi` | `fr.iamacat:matou-spi` | — (lib, pas de mod) | `matou:` | `matou-spi` (`FulzYVEA`, draft) | — (lib, plus tard) | DRAFT MR+CF |
| `matou-dev/bridge-1710` | `fr.iamacat:matou-bridge-1710` | `matoubridge` | — (traducteur, pas de contenu) | — (jamais publié seul) | — (jamais publié seul) | PROPOSED |
| `matou-dev/bridge-1122` | `fr.iamacat:matou-bridge-1122` | `matoubridge` | — (traducteur, pas de contenu) | — (jamais publié seul) | — (jamais publié seul) | PROPOSED |
| `matou-dev/bridge-1201` | `fr.iamacat:matou-bridge-1201` | `matoubridge` | — (traducteur, pas de contenu) | — (jamais publié seul) | — (jamais publié seul) | PROPOSED |
| `matou-dev/bridge-1165` | `fr.iamacat:matou-bridge-1165` | `matoubridge` | — (traducteur, pas de contenu) | — (jamais publié seul) | — (jamais publié seul) | PROPOSED |
| `matou-dev/example1` | — (mod, pas publié maven) | `example1` | `example1:` | `matou-example1` (`4QYpffM9`, draft) | `matou-example1` | DRAFT MR+CF |
| `matou-dev/minimap` | — (mod, pas publié maven) | `matouminimap` | `minimap:` | `matou-minimap` (`bUEFEfMK`, draft) | `matou-minimap` | DRAFT MR+CF |

Notes :
- `matoubridge` diffère volontairement de l'ancien `matouengine` (matou-engine)
  pour cohabiter dans une même instance pendant la migration.
- `bridge-1122` reuses modid `matoubridge`: safe, the two bridges never load
  in the same MC instance (disjoint versions).
- `matouminimap` : `minimap` seul est pris partout, d'où le préfixe.
- Historique `quentin452/*` (MatouMap, Cat-Culling, matoulib-core...) : gelé tel
  quel, jamais renommé (JitPack/saves).
- R2 (2026-09-09) : v1.0.0 = release source + server-drop (tags git,
  releases GitHub) ; les fiches restent DRAFT tant qu'il n'existe pas de
  release de mod chargeable (le bridge ne se publie jamais seul,
  example1/minimap n'ont pas encore de câblage FML).
