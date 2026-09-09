#!/bin/sh
# autopush.sh — commit+push multi-repos, dry-run par défaut.
# Usage : autopush.sh [-m "msg"] [--execute] [repo...]
#   sans --execute : affiche status + ahead/behind + gate, ne touche à rien.
#   avec --execute : -m requis, gate vert requis par repo (sinon sauté),
#                    jamais de --force, jamais de push à vide.
# Identité git = config de l'utilisateur (pas de -c ici).
set -eu
HUB=$(cd "$(dirname "$0")/.." && pwd)
PARENT=$(dirname "$HUB")
DEFAULT_REPOS="hub spi bridge-1710 bridge-1122 example1 minimap"
EXEC=0
MSG=""
REQ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --execute) EXEC=1; shift ;;
    -m) MSG="${2:? -m requiert un message}"; shift 2 ;;
    -h|--help)
      echo "usage: autopush.sh [-m \"msg\"] [--execute] [repo...]"; exit 0 ;;
    *) REQ="$REQ $1"; shift ;;
  esac
done
if [ -n "$REQ" ]; then
  REPOS="$REQ"
else
  REPOS="$DEFAULT_REPOS"
fi
if [ "$EXEC" -eq 1 ] && [ -z "$MSG" ]; then
  echo "FAIL : --execute requiert -m \"msg\""; exit 1
fi
FAIL=0
for r in $REPOS; do
  d="$PARENT/$r"
  if [ ! -d "$d/.git" ]; then
    echo "=== $r : SKIP (pas un clone) ==="; continue
  fi
  br=$(git -C "$d" branch --show-current)
  if [ "$br" != "main" ]; then
    echo "=== $r : SKIP (branche $br, seul main pousse) ==="; continue
  fi
  git -C "$d" fetch origin --quiet 2>/dev/null || true
  ah=$(git -C "$d" rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
  bh=$(git -C "$d" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
  st=$(git -C "$d" status --short)
  echo "=== $r (ahead=$ah behind=$bh) ==="
  if [ -n "$st" ]; then echo "$st"; fi
  GATE="none"
  if [ -x "$d/tools/check.sh" ]; then
    if (cd "$d" && sh tools/check.sh >/dev/null 2>&1); then
      GATE="vert"
    else
      GATE="ROUGE"
    fi
    echo "gate: $GATE"
  fi
  if command -v gh >/dev/null 2>&1; then
    slug="matou-dev/$r"
    if prs=$(gh pr list --repo "$slug" --limit 10 2>/dev/null); then
      if [ -n "$prs" ]; then echo "prs:"; echo "$prs"; else echo "prs: none"; fi
    else
      echo "prs: unknown (gh offline?)"
    fi
    if iss=$(gh issue list --repo "$slug" --limit 10 2>/dev/null); then
      if [ -n "$iss" ]; then echo "issues:"; echo "$iss"; else echo "issues: none"; fi
    else
      echo "issues: unknown (gh offline?)"
    fi
    if desc=$(gh repo view "$slug" --json description --jq .description 2>/dev/null); then
      if [ -z "$desc" ]; then
        echo "description: MISSING (stale — set gh repo edit $slug --description)"
      else
        echo "description: $desc"
      fi
    else
      echo "description: unknown (gh offline?)"
    fi
  fi
  if [ "$EXEC" -eq 0 ]; then
    if [ -n "$st" ]; then
      echo "dry-run : committerait + pousserait (-m requis)"
    elif [ "$ah" != "0" ] && [ "$ah" != "?" ]; then
      echo "dry-run : pousserait $ah commit(s)"
    else
      echo "dry-run : rien à faire"
    fi
    continue
  fi
  if [ "$GATE" = "ROUGE" ]; then
    echo "SKIP push (gate rouge)"; FAIL=1; continue
  fi
  if [ -z "$st" ] && { [ "$ah" = "0" ] || [ "$ah" = "?" ]; }; then
    echo "rien à faire"; continue
  fi
  if [ -n "$st" ]; then
    git -C "$d" add -A && git -C "$d" commit -m "$MSG" >/dev/null \
      || { echo "SKIP (commit refusé)"; FAIL=1; continue; }
  fi
  git -C "$d" push 2>&1 | tail -n 1 || { echo "SKIP (push refusé)"; FAIL=1; }
done
exit $FAIL
