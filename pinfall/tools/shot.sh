#!/usr/bin/env bash
# Render the game on an OFFSCREEN display and capture it.
#
# The first version ran on :1 and opened a Godot window over the owner's desktop, on top of the
# browser he was using. That is the same class of mess as leaving tabs open. Xvfb gives the game
# its own display: the GPU still does the work, nothing appears on his screen.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$HERE/art/shots}"; GAP="${2:-3}"
DISP=":77"
mkdir -p "$OUT"
Xvfb "$DISP" -screen 0 720x1280x24 >/dev/null 2>&1 &
XPID=$!
trap 'kill $GPID $XPID 2>/dev/null || true' EXIT
sleep 2
DISPLAY="$DISP" "$HOME/godot-bin/godot" --path "$HERE" --rendering-driver vulkan \
    --resolution 720x1280 >"$OUT/run.log" 2>&1 &
GPID=$!
sleep 5
for i in 1 2 3; do
  DISPLAY="$DISP" ffmpeg -loglevel error -f x11grab -video_size 720x1280 -i "$DISP" \
      -frames:v 1 -y "$OUT/frame_$i.png"
  sleep "$GAP"
done
kill $GPID 2>/dev/null || true; wait $GPID 2>/dev/null || true
kill $XPID 2>/dev/null || true
echo "frames in $OUT"
grep -icE "error" "$OUT/run.log" | sed 's/^/  errors in log: /'
grep -iE "ERROR|SCRIPT ERROR" "$OUT/run.log" | head -4 || true
