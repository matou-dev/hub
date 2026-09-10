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
#  4. declared gap only (PORT_QUEUE, decisions/BRIDGE_PARITY.md) :
#     a. full E_* catalog over forge/src + java/src (shipped code, never
#        tools/) : a code missing in any bridge must be cited in hub
#        decisions/*.md (the tranche that introduced it) — an uncited
#        local code is a forgotten port, FAIL.
#     b. shells (files containing "parity shell") must cite
#        decisions/<FILE>.md present in hub decisions/ — an unpointed
#        shell is an undeclared stub, FAIL.
#     c. gap report : per-bridge shell count + local-code count, always
#        printed (the visible metric; shrinks tranche by tranche, a port
#        flips its PORT_QUEUE cell in the same commit).
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
  (cd "$b" && rg -o --no-filename -N 'E_[A-Z0-9]+_[A-Z0-9_]+' forge/src java/src 2>/dev/null | sort -u || true) > "$tmp/all-$n"
  (cd "$b" && rg -l --no-messages 'parity shell' forge/src 2>/dev/null || true) > "$tmp/shells-$n"
  echo "$b" > "$tmp/name-$n"
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
# Dim 4a : every code missing anywhere must be cited in hub decisions/.
sort -u "$tmp"/all-* > "$tmp/union"
i=0
while [ "$i" -lt "$n" ]; do
  : > "$tmp/local-$i"
  i=$((i + 1))
done
fail=0
while IFS= read -r code; do
  [ -n "$code" ] || continue
  missing=""; i=0
  while [ "$i" -lt "$n" ]; do
    if ! grep -qxF "$code" "$tmp/all-$i"; then
      missing="$missing $(cat "$tmp/name-$i")"
    fi
    i=$((i + 1))
  done
  if [ -n "$missing" ]; then
    if ! rg -q -F -- "$code" decisions/; then
      echo "FAIL bridge-parity : undeclared local code <$code> (missing in$missing — cite it in hub decisions/*.md, PORT_QUEUE in decisions/BRIDGE_PARITY.md)"
      fail=1
    fi
    i=0
    while [ "$i" -lt "$n" ]; do
      if grep -qxF "$code" "$tmp/all-$i"; then
        echo "$code" >> "$tmp/local-$i"
      fi
      i=$((i + 1))
    done
  fi
done < "$tmp/union"
[ "$fail" = "0" ] || exit 1
echo "ok (bridge-parity-codes : full E_* catalog declared)"
# Dim 4b : every shell must point at a hub decision file on disk.
i=0
while [ "$i" -lt "$n" ]; do
  b=$(cat "$tmp/name-$i")
  while IFS= read -r sh; do
    [ -n "$sh" ] || continue
    cited=$(rg -o -N 'decisions/[A-Za-z0-9_.\-]+\.md' "$b/$sh" 2>/dev/null || true)
    [ -n "$cited" ] || { echo "FAIL bridge-parity : unpointed shell <$b/$sh> (cite decisions/<FILE>.md — PORT_QUEUE in decisions/BRIDGE_PARITY.md)"; exit 1; }
    for tok in $cited; do
      [ -f "$tok" ] || { echo "FAIL bridge-parity : shell <$b/$sh> points at dead <$tok>"; exit 1; }
    done
  done < "$tmp/shells-$i"
  i=$((i + 1))
done
echo "ok (bridge-parity-shells : all shells declared)"
# Dim 4c : visible gap metric, always printed.
i=0
while [ "$i" -lt "$n" ]; do
  b=$(cat "$tmp/name-$i")
  shells=$(grep -c . "$tmp/shells-$i" || true)
  local=$(grep -c . "$tmp/local-$i" || true)
  echo "ok (bridge-parity-gap : $b shells=$shells local-codes=$local)"
  i=$((i + 1))
done
