#!/bin/sh
# Gate hub : table NAMES à 7 colonnes + fichiers doctrine présents + parité
# STATE.md/ROADMAP.md (bloc GENERATED, SSOT = ROADMAP).
# Usage : check.sh [--fix] (régénère le bloc dérivé avant de vérifier).
set -eu
cd "$(dirname "$0")/.."
MODE=""
if [ "${1:-}" = "--fix" ]; then
  MODE="--fix"
elif [ $# -gt 0 ]; then
  echo "FAIL hub-check : unknown arg <$1> (want [--fix])"; exit 1
fi
awk -F'|' '/^\| `matou-dev\// { if (NF != 9) { print "FAIL names-table : " $0; bad = 1 } } END { exit bad }' NAMES.md \
  || { echo "FAIL names-table"; exit 1; }
for f in AGENTS.md STATE.md ROADMAP.md NAMES.md; do
  [ -f "$f" ] || { echo "FAIL hub-missing : $f"; exit 1; }
done
echo "ok (hub-check)"
python3 "$(dirname "$0")/check_state.py" $MODE
sh "$(dirname "$0")/check-bridges.sh"
