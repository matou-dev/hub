#!/bin/sh
# Gate bridge-parity (hub) : les bridges ne derivent ni en version ni en
# comportement sans le dire.
#  1. SPI_PIN : les deux bridges epinglent le meme SPI (sinon l'un est en
#     avance/retard — re-valider le retardataire, puis bumper son pin).
#  2. forge file-set : memes fichiers des deux cotes (un fichier ajoute
#     d'un seul cote = report oublie).
#  3. catalogue E_FORGE_* : memes codes d'erreur (un chemin bruyant ajoute
#     d'un cote doit exister de l'autre).
# Un sibling absent = skip bruyant (le CI hub checkout les siblings, cf.
# .github/workflows/check.yml) — jamais de rouge sans cause en local.
set -eu
cd "$(dirname "$0")/.."
B1710=../bridge-1710
B1122=../bridge-1122
if [ ! -d "$B1710" ] || [ ! -d "$B1122" ]; then
  echo "skip bridge-parity (siblings absents : cloner bridge-1710+bridge-1122 en siblings)"
  exit 0
fi
[ -f "$B1710/SPI_PIN" ] || { echo "FAIL bridge-parity : ../bridge-1710/SPI_PIN absent"; exit 1; }
[ -f "$B1122/SPI_PIN" ] || { echo "FAIL bridge-parity : ../bridge-1122/SPI_PIN absent"; exit 1; }
p1710=$(tr -d '[:space:]' < "$B1710/SPI_PIN")
p1122=$(tr -d '[:space:]' < "$B1122/SPI_PIN")
[ -n "$p1710" ] || { echo "FAIL bridge-parity : empty ../bridge-1710/SPI_PIN"; exit 1; }
[ -n "$p1122" ] || { echo "FAIL bridge-parity : empty ../bridge-1122/SPI_PIN"; exit 1; }
if [ "$p1710" != "$p1122" ]; then
  echo "FAIL bridge-parity : pins differ <1710:$p1710> <1122:$p1122> (re-validate the laggard, then bump its SPI_PIN)"
  exit 1
fi
echo "ok (bridge-parity-pin : $p1710)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
(cd "$B1710" && find forge/src -name '*.java' | sed 's|.*/||' | sort) > "$tmp/files1710"
(cd "$B1122" && find forge/src -name '*.java' | sed 's|.*/||' | sort) > "$tmp/files1122"
if ! cmp -s "$tmp/files1710" "$tmp/files1122"; then
  echo "FAIL bridge-parity : forge file-set differs"
  diff "$tmp/files1710" "$tmp/files1122" || true
  exit 1
fi
echo "ok (bridge-parity-files)"
(cd "$B1710" && rg -o --no-filename 'E_FORGE_[A-Z_]+' forge/src | sort -u) > "$tmp/err1710"
(cd "$B1122" && rg -o --no-filename 'E_FORGE_[A-Z_]+' forge/src | sort -u) > "$tmp/err1122"
if ! cmp -s "$tmp/err1710" "$tmp/err1122"; then
  echo "FAIL bridge-parity : E_FORGE_* catalog differs"
  diff "$tmp/err1710" "$tmp/err1122" || true
  exit 1
fi
echo "ok (bridge-parity-errors)"
