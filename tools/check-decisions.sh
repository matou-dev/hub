#!/bin/sh
# Gate decisions-parity (hub) : front-matter ferme + index GENERATED en
# parite + liens decisions/*.md morts refuses bruyamment.
# Usage : check-decisions.sh [--fix] (regenere le bloc derive).
set -eu
cd "$(dirname "$0")/.."
MODE=""
if [ "${1:-}" = "--fix" ]; then
  MODE="--fix"
elif [ $# -gt 0 ]; then
  echo "FAIL decisions-check : unknown arg <$1> (want [--fix])"; exit 1
fi
python3 "$(dirname "$0")/check_decisions.py" $MODE
