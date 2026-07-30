#!/usr/bin/env bash
# b43-resume-verify — run after a suspend + wake cycle on macbook-pro-9-2
# to verify the 50-b43-reload systemd-sleep hook actually silences the
# mac80211 EDCA-init WARN_ON on resume. Produces pass/fail + the
# relevant journal lines.
#
# Task: AI-tasks.json -> mbp-b43-resume-warn

set -euo pipefail

if [[ ${HOSTNAME:-$(hostname)} != "macbook-pro-9-2" ]]; then
  echo "ERROR: run on macbook-pro-9-2. current: ${HOSTNAME:-$(hostname)}" >&2
  exit 1
fi

# Last resume event — use journalctl suspend / wake markers from current boot.
RESUME_TS=$(journalctl -b --no-pager 2>&1 |
  grep -E 'PM: suspend exit|systemd-sleep.*Post-sleep' |
  tail -1 | awk '{print $1,$2,$3}')

if [[ -z $RESUME_TS ]]; then
  echo "No resume event detected this boot. Suspend + wake first, then re-run."
  exit 1
fi

echo "=== Last resume: $RESUME_TS ==="
echo ""

# Look for the specific mac80211 WARN after resume.
WARN_HITS=$(journalctl -k -b --since "$RESUME_TS" --no-pager 2>&1 |
  grep -iE "CW_min|CW_max|drv_conf_tx|EDCA" | head -20 || true)

echo "--- WARN/trace lines after last resume ---"
if [[ -z $WARN_HITS ]]; then
  echo "(none — fix appears effective)"
  echo ""
  echo "PASS: no b43 EDCA-init WARN in the post-resume journal."
  exit 0
else
  echo "$WARN_HITS"
  echo ""
  echo "FAIL: mac80211 / b43 warnings still firing on resume."
  exit 1
fi
