#!/bin/sh
set -eu
HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HARNESS_DIR/.build"
A="${1:-}"
B="${2:-}"
[ -n "$A" ] && [ -n "$B" ] || { echo "usage: diff.sh <dirA> <dirB>" >&2; exit 2; }
[ -x "$BIN/imagediff" ] || "$HARNESS_DIR/build.sh" >/dev/null

REPORT="$B/report-vs-$(basename "$A").txt"
{
  echo "# snapshot diff"
  echo "a=$A"
  echo "b=$B"
  echo
  echo "## window geometry"
  if [ -f "$A/windows.txt" ] && [ -f "$B/windows.txt" ]; then
    diff -u "$A/windows.txt" "$B/windows.txt" || true
  else
    echo "(missing windows.txt)"
  fi
  echo
  echo "## ax structure (normalized)"
  if [ -f "$A/ax-norm.txt" ] && [ -f "$B/ax-norm.txt" ]; then
    diff -u "$A/ax-norm.txt" "$B/ax-norm.txt" || true
  else
    echo "(missing ax-norm.txt)"
  fi
  echo
  echo "## images"
  for img in "$A"/window-*.png; do
    [ -e "$img" ] || continue
    name="$(basename "$img")"
    if [ -f "$B/$name" ]; then
      echo "--- $name"
      "$BIN/imagediff" "$img" "$B/$name" --out "$B/heat-$name" --threshold 8 || true
    else
      echo "--- $name (missing in B)"
    fi
  done
} > "$REPORT"
echo "wrote $REPORT"
