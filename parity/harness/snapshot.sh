#!/bin/sh
set -eu
HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
PARITY_DIR="$(dirname "$HARNESS_DIR")"
BIN="$HARNESS_DIR/.build"
APP="${1:-}"
STATE="${2:-}"
case "$APP" in
  paste) BUNDLE="com.wiheads.paste" ;;
  copydock) BUNDLE="dev.corismix.copydock" ;;
  *)
    echo "usage: snapshot.sh <paste|copydock> <state> [--screen]" >&2
    exit 2
    ;;
esac
[ -n "$STATE" ] || { echo "usage: snapshot.sh <paste|copydock> <state> [--screen]" >&2; exit 2; }
[ -x "$BIN/axdump" ] || "$HARNESS_DIR/build.sh" >/dev/null

OUT="$PARITY_DIR/captures/$APP/$STATE"
mkdir -p "$OUT"

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$OUT/date.txt"
"$BIN/axdump" "$BUNDLE" --windows --format json --out "$OUT/windows.json"
"$BIN/axdump" "$BUNDLE" --windows --format text --out "$OUT/windows.txt"
"$BIN/axdump" "$BUNDLE" --format json --out "$OUT/ax-raw.json"
"$BIN/axdump" "$BUNDLE" --format text --out "$OUT/ax.txt"
"$BIN/axdump" "$BUNDLE" --format norm --out "$OUT/ax-norm.txt"

python3 - "$OUT/windows.json" "$OUT" <<'PY'
import json, os, subprocess, sys
wins = json.load(open(sys.argv[1]))
outdir = sys.argv[2]
idx = 0
for w in wins:
    b = w.get("bounds", {})
    if b.get("w", 0) < 2 or b.get("h", 0) < 2:
        continue
    path = os.path.join(outdir, "window-%d.png" % idx)
    subprocess.run(["screencapture", "-l", str(w["id"]), "-x", "-o", path], check=False)
    idx += 1
print("captured %d windows" % idx)
PY

if [ "${3:-}" = "--screen" ]; then
  screencapture -x "$OUT/screen.png"
fi

defaults read "$BUNDLE" > "$OUT/defaults.txt" 2>/dev/null || true
echo "snapshot: $OUT"
