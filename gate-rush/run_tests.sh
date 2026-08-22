#!/usr/bin/env bash
# One command that runs every guarantee this game has, so a change cannot quietly break one.
# Owner's standard: nothing counts as done without a real artefact.
set -u
GODOT=${GODOT:-$HOME/godot-bin/godot}
cd "$(dirname "$0")" || exit 1
fails=0
for t in balance_test play_test fight_test input_test break_test shot_repeat_test dupe_test claims_test run_levels; do
  out=$(timeout 300 "$GODOT" --headless --path . --script "res://$t.gd" 2>&1)
  rc=$?
  line=$(printf '%s\n' "$out" | grep -E "PASS|FAIL|outside the playable window|perfect play wins" | tail -1)
  if [ $rc -ne 0 ] || printf '%s' "$line" | grep -q "FAIL"; then
    fails=$((fails+1)); printf '  FAIL  %-14s %s\n' "$t" "$line"
  else
    printf '  ok    %-14s %s\n' "$t" "$line"
  fi
done
echo "--- $fails failing"
exit $fails
