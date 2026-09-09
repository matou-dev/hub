#!/bin/sh
# Gate bridge-parity (hub) : les bridges ne derivent ni en version ni en
# comportement sans le dire. Discovers ../bridge-*/ (any MC sfx, including
# scaffolded ones from tools/scaffold-bridge.sh).
#  1. SPI_PIN : tous les bridges epinglent le meme SPI (sinon l'un est en
#     avance/retard — re-valider le retardataire, puis bumper son pin).
#  2. forge file-set : memes fichiers partout (un fichier ajoute d'un seul
#     cote = report oublie).
#  3. catalogue E_FORGE_* : memes codes d'erreur (un chemin bruyant ajoute
#     d'un cote doit exister partout).
# No sibling = skip bruyant (le CI hub checkout les siblings, cf.
# .github/workflows/check.yml) — jamais de rouge sans cause en local.
set -eu
cd "$(dirname "$0")/.."
set -- ../bridge-*/
if [ ! -d "$1" ]; then
  echo "skip bridge-parity (no ../bridge-*/ siblings : clone bridges as siblings)"
  exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
first=""; pin0=""; n=0
for b in "$@"; do
  b=${b%/}
  [ -f "$b/SPI_PIN" ] || { echo "FAIL bridge-parity : $b/SPI_PIN absent"; exit 1; }
  pin=$(tr -d '[:space:]' < "$b/SPI_PIN")
  [ -n "$pin" ] || { echo "FAIL bridge-parity : empty $b/SPI_PIN"; exit 1; }
  (cd "$b" && find forge/src -name '*.java' | sed 's|.*/||' | sort) > "$tmp/files-$n"
  (cd "$b" && rg -o --no-filename 'E_FORGE_[A-Z_]+' forge/src | sort -u) > "$tmp/err-$n"
  if [ -z "$first" ]; then
    first="$b"; pin0="$pin"
  else
    if [ "$pin" != "$pin0" ]; then
      echo "FAIL bridge-parity : pins differ <$first:$pin0> <$b:$pin> (re-validate the laggard, then bump its SPI_PIN)"
      exit 1
    fi
    if ! cmp -s "$tmp/files-0" "$tmp/files-$n"; then
      echo "FAIL bridge-parity : forge file-set differs ($first vs $b)"
      diff "$tmp/files-0" "$tmp/files-$n" || true
      exit 1
    fi
    if ! cmp -s "$tmp/err-0" "$tmp/err-$n"; then
      echo "FAIL bridge-parity : E_FORGE_* catalog differs ($first vs $b)"
      diff "$tmp/err-0" "$tmp/err-$n" || true
      exit 1
    fi
  fi
  n=$((n + 1))
done
echo "ok (bridge-parity-pin : $pin0 over $n bridges)"
echo "ok (bridge-parity-files)"
echo "ok (bridge-parity-errors)"
