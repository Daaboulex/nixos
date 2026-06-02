#!/usr/bin/env bash
# vfio-phase1-probe — gather the data needed to unblock VFIO Phase 2 + 3
# tasks (BAR2 resize + SDDM KWIN_DRM drop-in).
#
# Run on ryzen-9950x3d only — produces a report file next to the script.
# Copy the report back to the MBP session to unblock the remaining VFIO
# work in AI-tasks.json:
#   vfio-seamless-handoff-phase1-verify
#   vfio-bar2-resize
#   vfio-sddm-kwin-override

set -euo pipefail

if [[ ${HOSTNAME:-$(hostname)} != "ryzen-9950x3d" ]]; then
  echo "ERROR: run on ryzen-9950x3d. current: ${HOSTNAME:-$(hostname)}" >&2
  exit 1
fi

REPORT="${1:-/tmp/vfio-phase1-$(date +%Y-%m-%d-%H%M).txt}"
{
  echo "=== vfio-phase1-probe $(date -Iseconds) $(uname -sr) ==="
  echo ""
  echo "--- 1. dGPU + audio device identity (confirm 1002:ab40 audio ID) ---"
  lspci -nnk | grep -A3 "03:00" || true
  echo ""
  echo "--- 2. BAR2 resize capability (expect 'Current size', resize offsets) ---"
  for f in /sys/bus/pci/devices/0000:03:00.0/resource2_resize \
    /sys/bus/pci/devices/0000:03:00.0/resource2; do
    if [[ -r $f ]]; then
      echo "$f:"
      cat "$f"
      echo ""
    else
      echo "$f: missing/unreadable"
    fi
  done
  echo ""
  echo "--- 3. Session env KWIN_DRM_DEVICES propagation ---"
  if command -v systemctl >/dev/null; then
    systemctl --user show-environment 2>&1 | grep -i KWIN_DRM || echo "KWIN_DRM_* NOT set in user env"
  fi
  echo ""
  echo "--- 4. PCI BAR + capability dump for 0000:03:00.0 ---"
  lspci -s 03:00 -vvv 2>&1 | head -50 || true
  echo ""
  echo "--- 5. amdgpu / vfio binding state ---"
  driver_link=/sys/bus/pci/devices/0000:03:00.0/driver
  if [[ -e $driver_link ]]; then
    echo "$driver_link -> $(readlink "$driver_link")"
  else
    echo "$driver_link: not bound"
  fi
  echo ""
  echo "--- 6. Kernel log hints (D3, rebar, amdgpu errors last boot) ---"
  journalctl -k -b --no-pager 2>&1 | grep -iE "rebar|D3|vfio|amdgpu|03:00" | head -30 || true
  echo ""
  echo "=== end report ==="
} >"$REPORT"

echo "Report: $REPORT"
echo "Copy this file to MBP + paste contents into"
echo "  .ai-context/.superpowers/specs/2026-04-22-seamless-gpu-handoff.md"
echo "under the 'Phase 1 data' section."
