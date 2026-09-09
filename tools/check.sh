#!/bin/sh
# Gate hub : table NAMES à 7 colonnes + fichiers doctrine présents.
set -eu
cd "$(dirname "$0")/.."
awk -F'|' '/^\| `matou-dev\// { if (NF != 9) { print "FAIL names-table : " $0; bad = 1 } } END { exit bad }' NAMES.md \
  || { echo "FAIL names-table"; exit 1; }
for f in AGENTS.md STATE.md ROADMAP.md NAMES.md; do
  [ -f "$f" ] || { echo "FAIL hub-missing : $f"; exit 1; }
done
echo "ok (hub-check)"
