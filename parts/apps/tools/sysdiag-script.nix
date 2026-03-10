# sysdiag — Comprehensive NixOS system diagnostics script
# Split from sysdiag.nix module to keep module definition lean.
# This file returns a function: pkgs -> script-string
{ pkgs }:

''
#!/usr/bin/env bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

section() {
  echo ""
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
  echo -e "''${BOLD}''${WHITE}  $1''${NC}"
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
}

subsection() { echo -e "''${YELLOW}▸ $1''${NC}"; }
info() { echo -e "  ''${GREEN}$1:''${NC} $2"; }

# Hardware detection
HAS_AMD_CPU=false; HAS_INTEL_CPU=false; HAS_AMD_GPU=false; HAS_NVIDIA_GPU=false; HAS_INTEL_GPU=false; HAS_BATTERY=false
${pkgs.gnugrep}/bin/grep -qi "AMD" /proc/cpuinfo && HAS_AMD_CPU=true
${pkgs.gnugrep}/bin/grep -qi "Intel" /proc/cpuinfo && HAS_INTEL_CPU=true
${pkgs.pciutils}/bin/lspci 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi "VGA.*AMD\|Display.*AMD\|3D.*AMD" && HAS_AMD_GPU=true
${pkgs.pciutils}/bin/lspci 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi "VGA.*NVIDIA\|3D.*NVIDIA" && HAS_NVIDIA_GPU=true
${pkgs.pciutils}/bin/lspci 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi "VGA.*Intel" && HAS_INTEL_GPU=true
[ -d /sys/class/power_supply/BAT0 ] && HAS_BATTERY=true

# ═══════════════════════════════════════════════════════════════════════
# INDIVIDUAL DIAGNOSTIC FUNCTIONS (FULL OUTPUT)
# ═══════════════════════════════════════════════════════════════════════

show_cpu() {
  section "🔧 CPU INFORMATION (FULL)"

  subsection "Processor"
  cat /proc/cpuinfo | ${pkgs.gnugrep}/bin/grep -E "model name|cpu MHz|cache size|cpu cores|siblings" | head -10

  subsection "CPU Topology"
  ${pkgs.util-linux}/bin/lscpu 2>/dev/null || cat /proc/cpuinfo | head -30

  if $HAS_AMD_CPU; then
    subsection "AMD P-State"
    for f in /sys/devices/system/cpu/amd_pstate/*; do
      [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
    done

    subsection "AMD CPU Features"
    for f in /sys/devices/system/cpu/cpu0/cpufreq/*; do
      [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
    done
  fi

  if $HAS_INTEL_CPU; then
    subsection "Intel P-State"
    for f in /sys/devices/system/cpu/intel_pstate/*; do
      [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
    done
  fi

  subsection "All CPU Frequencies"
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    if [ -f "$cpu/cpufreq/scaling_cur_freq" ]; then
      FREQ=$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null)
      FREQ_MHZ=$((FREQ / 1000))
      GOV=$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null)
      echo -e "  ''${GRAY}$(basename $cpu): ''${WHITE}$FREQ_MHZ MHz''${NC} ($GOV)"
    fi
  done

  subsection "CPU Temperatures (Full)"
  ${pkgs.lm_sensors}/bin/sensors 2>/dev/null || echo "  lm_sensors not available"
}

show_gpu() {
  section "🎮 GPU INFORMATION (FULL)"

  subsection "All GPUs (lspci)"
  ${pkgs.pciutils}/bin/lspci -v 2>/dev/null | ${pkgs.gnugrep}/bin/grep -A 20 "VGA\|3D\|Display"

  if $HAS_AMD_GPU; then
    subsection "AMD GPU Sysfs"
    for gpu in /sys/class/drm/card*/device; do
      [ -d "$gpu" ] || continue
      echo -e "  ''${WHITE}$(dirname $gpu | xargs basename)''${NC}"
      for f in gpu_busy_percent mem_info_vram_used mem_info_vram_total power_dpm_state power_dpm_force_performance_level pp_power_profile_mode current_link_speed current_link_width; do
        [ -f "$gpu/$f" ] && info "  $f" "$(cat $gpu/$f 2>/dev/null | head -1)"
      done
      for hwmon in $gpu/hwmon/hwmon*; do
        [ -f "$hwmon/temp1_input" ] && info "  temp" "$(($(cat $hwmon/temp1_input) / 1000))°C"
      done
    done

    subsection "RADV/Mesa Environment"
    env | ${pkgs.gnugrep}/bin/grep -E "RADV|MESA|AMD|VK_" | sort || echo "  No RADV env vars set"

    if command -v lact &>/dev/null && systemctl is-active --quiet lact; then
      subsection "LACT GPU Info"
      lact cli info 2>/dev/null || echo "  LACT not responding"
    fi
  fi

  if $HAS_NVIDIA_GPU; then
    subsection "NVIDIA GPU (nvidia-smi)"
    nvidia-smi 2>/dev/null || echo "  nvidia-smi not available"
  fi

  subsection "Vulkan (Full)"
  ${pkgs.vulkan-tools}/bin/vulkaninfo 2>/dev/null || echo "  vulkaninfo not available"

  subsection "OpenGL (Full)"
  ${pkgs.mesa-demos}/bin/glxinfo 2>/dev/null | head -50 || echo "  glxinfo not available"
}

show_memory() {
  section "💾 MEMORY (FULL)"

  subsection "Memory Info"
  free -h

  subsection "/proc/meminfo"
  cat /proc/meminfo

  subsection "Swap Details"
  swapon --show 2>/dev/null || cat /proc/swaps

  subsection "All Memory Consumers (top 20)"
  ps aux --sort=-%mem | head -21

  subsection "Shared Memory"
  ipcs -m 2>/dev/null || echo "  N/A"
}

show_storage() {
  section "💿 STORAGE (FULL)"

  subsection "Block Devices"
  ${pkgs.util-linux}/bin/lsblk -f

  subsection "Disk Usage"
  df -h

  subsection "NVMe Devices"
  for nvme in /sys/class/nvme/nvme*; do
    [ -d "$nvme" ] || continue
    echo -e "  ''${WHITE}$(basename $nvme)''${NC}"
    for f in model serial firmware_rev; do
      [ -f "$nvme/$f" ] && info "  $f" "$(cat $nvme/$f 2>/dev/null | xargs)"
    done
    for hwmon in $nvme/hwmon*; do
      [ -f "$hwmon/temp1_input" ] && info "  temp" "$(($(cat $hwmon/temp1_input) / 1000))°C"
    done
  done

  subsection "SMART Info (All Drives)"
  for disk in /dev/nvme?n1 /dev/sd?; do
    [ -b "$disk" ] || continue
    echo -e "  ''${WHITE}$disk''${NC}"
    sudo ${pkgs.smartmontools}/bin/smartctl -a "$disk" 2>/dev/null | head -40
    echo ""
  done

  subsection "I/O Schedulers"
  for disk in /sys/block/*/queue/scheduler; do
    [ -f "$disk" ] && info "$(echo $disk | cut -d/ -f4)" "$(cat $disk)"
  done
}

show_network() {
  section "🌐 NETWORK (FULL)"

  subsection "Interfaces"
  ${pkgs.iproute2}/bin/ip addr

  subsection "Routes"
  ${pkgs.iproute2}/bin/ip route

  subsection "DNS"
  cat /etc/resolv.conf

  subsection "Listening Ports"
  ${pkgs.iproute2}/bin/ss -tlnp 2>/dev/null

  subsection "Active Connections"
  ${pkgs.iproute2}/bin/ss -tnp 2>/dev/null | head -20

  if command -v ${pkgs.ethtool}/bin/ethtool &>/dev/null; then
    subsection "Ethernet Details"
    for iface in $(${pkgs.iproute2}/bin/ip -o link | ${pkgs.gawk}/bin/awk -F': ' '/: e/{print $2}'); do
      echo -e "  ''${WHITE}$iface''${NC}"
      ${pkgs.ethtool}/bin/ethtool "$iface" 2>/dev/null | head -20
    done
  fi
}

show_services() {
  section "🔌 SERVICES (FULL)"

  subsection "All Running System Services"
  systemctl list-units --type=service --state=running --no-pager

  subsection "All Running User Services"
  systemctl --user list-units --type=service --state=running --no-pager

  subsection "Failed System Services"
  systemctl list-units --type=service --state=failed --no-pager

  subsection "Failed User Services"
  systemctl --user list-units --type=service --state=failed --no-pager

  subsection "All Enabled Services"
  systemctl list-unit-files --type=service --state=enabled --no-pager
}

show_kernel() {
  section "🐧 KERNEL (FULL)"

  subsection "Kernel Info"
  uname -a

  subsection "Kernel Cmdline"
  cat /proc/cmdline

  subsection "Boot Timing"
  systemd-analyze 2>/dev/null
  systemd-analyze blame 2>/dev/null

  subsection "All Loaded Modules"
  ${pkgs.kmod}/bin/lsmod | sort

  subsection "Kernel Messages (last 100)"
  dmesg | tail -100
}

show_scheduler() {
  section "⚡ SCHEDULER (FULL)"

  subsection "Built-in Kernel Scheduler"
  if [ -f /proc/sys/kernel/sched_bore ]; then
    info "Primary" "Bore (Burst-Oriented Response Enhancer)"
    info "Burstness" "$(cat /proc/sys/kernel/sched_bore 2>/dev/null)"
  elif [ -f /proc/sys/kernel/sched_bmq_prio ]; then
    info "Primary" "BMQ (BitMap Queue)"
  elif [ -f /proc/sys/kernel/sched_pds_yield_type ]; then
    info "Primary" "PDS (Priority Designo Scheduler)"
  else
    info "Primary" "EEVDF / Standard CFS"
  fi

  subsection "Sched_ext (BPF)"
  if [ -d /sys/kernel/sched_ext ]; then
    if [ -f /sys/kernel/sched_ext/root/ops ]; then
        info "Status" "Enabled and Active"
        info "Active Ops" "$(cat /sys/kernel/sched_ext/root/ops 2>/dev/null | xargs)"
    else
        info "Status" "Enabled (No BPF scheduler loaded)"
    fi
    for f in /sys/kernel/sched_ext/*; do
      [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
    done
  else
    info "Status" "Not available in kernel"
  fi

  subsection "Running scx Processes"
  pgrep -a 'scx_' 2>/dev/null || echo "  No scx scheduler running"

  subsection "scx Service Status"
  systemctl status scx.service 2>/dev/null || echo "  scx.service not found"

  subsection "CPU Topology"
  for cpu in /sys/devices/system/cpu/cpu0; do
    for f in $cpu/topology/*; do
      [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
    done
  done
}

show_errors() {
  section "⚠️  ERRORS (FULL)"

  subsection "dmesg Errors (All)"
  dmesg --level=err,crit,alert,emerg 2>/dev/null || dmesg | ${pkgs.gnugrep}/bin/grep -iE "error|fail|crit"

  subsection "Journal Errors (This Boot)"
  journalctl -b -p err --no-pager
}

show_display() {
  section "🖥️  DISPLAY (FULL)"

  subsection "Session Info"
  # Try to get session info, fallback to loginctl for sudo
  SESSION_TYPE="''${XDG_SESSION_TYPE:-}"
  SESSION_DESKTOP="''${XDG_CURRENT_DESKTOP:-}"
  if [ -z "$SESSION_TYPE" ] && command -v loginctl &>/dev/null; then
     SESSION_ID=$(loginctl session-status | head -n 1 | awk '{print $1}' 2>/dev/null)
     if [ -n "$SESSION_ID" ]; then
       SESSION_TYPE=$(loginctl show-session "$SESSION_ID" -p Type --value 2>/dev/null)
       SESSION_DESKTOP=$(loginctl show-session "$SESSION_ID" -p Desktop --value 2>/dev/null)
     fi
  fi
  info "XDG_SESSION_TYPE" "''${SESSION_TYPE:-unknown}"
  info "XDG_CURRENT_DESKTOP" "''${SESSION_DESKTOP:-unknown}"
  info "WAYLAND_DISPLAY" "''${WAYLAND_DISPLAY:-not set}"
  info "DISPLAY" "''${DISPLAY:-not set}"

  subsection "DRM Devices"
  for card in /sys/class/drm/card*; do
    [ -d "$card" ] && info "$(basename $card)" "$(cat $card/device/driver/module/name 2>/dev/null || echo 'unknown')"
  done

  subsection "Monitor Info"
  if [ "$SESSION_TYPE" = "wayland" ]; then
    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --outputs 2>/dev/null || ${pkgs.wlr-randr}/bin/wlr-randr 2>/dev/null || echo "  No Wayland monitor tool available"
  else
    xrandr --verbose 2>/dev/null || echo "  xrandr not available"
  fi

  subsection "Framebuffer"
  cat /sys/class/graphics/fb0/modes 2>/dev/null || echo "  N/A"
}

show_help() {
  echo -e "''${MAGENTA}"
  echo "  ╔═══════════════════════════════════════════════════════════════════════╗"
  echo "  ║                    🔍 NIXOS SYSTEM DIAGNOSTICS                        ║"
  echo "  ╚═══════════════════════════════════════════════════════════════════════╝"
  echo -e "''${NC}"
  echo ""
  echo -e "''${WHITE}Usage:''${NC} sysdiag [OPTION]"
  echo ""
  echo -e "''${WHITE}Options:''${NC}"
  echo -e "  ''${GREEN}(none)''${NC}      Show overview of all sections (default)"
  echo -e "  ''${GREEN}--cpu''${NC}       Full CPU information"
  echo -e "  ''${GREEN}--gpu''${NC}       Full GPU information"
  echo -e "  ''${GREEN}--memory''${NC}    Full memory information"
  echo -e "  ''${GREEN}--storage''${NC}   Full storage/disk information"
  echo -e "  ''${GREEN}--network''${NC}   Full network information"
  echo -e "  ''${GREEN}--services''${NC}  Full services status"
  echo -e "  ''${GREEN}--kernel''${NC}    Full kernel info and dmesg"
  echo -e "  ''${GREEN}--scheduler''${NC} Full scheduler (sched_ext) info"
  echo -e "  ''${GREEN}--display''${NC}   Full display/monitor info"
  echo -e "  ''${GREEN}--errors''${NC}    Full error logs (dmesg + journal)"
  echo -e "  ''${GREEN}--all''${NC}       Show ALL sections with FULL output"
  echo -e "  ''${GREEN}--help''${NC}      Show this help"
  echo ""
}

show_overview() {
  echo -e "''${MAGENTA}"
  echo "  ╔═══════════════════════════════════════════════════════════════════════╗"
  echo "  ║                    🔍 NIXOS SYSTEM DIAGNOSTICS                        ║"
  echo "  ╚═══════════════════════════════════════════════════════════════════════╝"
  echo -e "''${NC}"

  # System overview
  section "📊 SYSTEM OVERVIEW"
  ${pkgs.fastfetch}/bin/fastfetch --logo none 2>/dev/null || { info "Hostname" "$(hostname)"; info "Kernel" "$(uname -r)"; }

  # CPU summary
  section "🔧 CPU"
  info "Model" "$(${pkgs.gnugrep}/bin/grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
  info "Cores/Threads" "$(${pkgs.gnugrep}/bin/grep -c processor /proc/cpuinfo)"
  info "Governor" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
  if $HAS_AMD_CPU && [ -f /sys/devices/system/cpu/amd_pstate/status ]; then
    info "P-State" "$(cat /sys/devices/system/cpu/amd_pstate/status)"
    [ -f /sys/devices/system/cpu/amd_pstate/prefcore ] && info "Prefcore" "$(cat /sys/devices/system/cpu/amd_pstate/prefcore 2>/dev/null)"
  fi
  MAX_FREQ=0; MIN_FREQ=999999
  for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    [ -f "$cpu" ] || continue
    FREQ=$(($(cat $cpu) / 1000))
    [ $FREQ -gt $MAX_FREQ ] && MAX_FREQ=$FREQ
    [ $FREQ -lt $MIN_FREQ ] && MIN_FREQ=$FREQ
  done
  info "Frequency" "$MIN_FREQ - $MAX_FREQ MHz"
  ${pkgs.lm_sensors}/bin/sensors 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E "Tctl|Tdie|Package" | head -2 | while read l; do echo "  $l"; done

  # GPU summary
  section "🎮 GPU"
  for gpu in /sys/class/drm/card*/device; do
    [ -d "$gpu" ] || continue
    CARD=$(dirname $gpu | xargs basename)
    PCI_ADDR=$(basename $(readlink -f $gpu) 2>/dev/null)
    GPU_NAME=$(${pkgs.pciutils}/bin/lspci -s "$PCI_ADDR" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/.*: //' | cut -c1-50)
    VRAM_USED=$(cat $gpu/mem_info_vram_used 2>/dev/null)
    VRAM_TOTAL=$(cat $gpu/mem_info_vram_total 2>/dev/null)
    TEMP="N/A"
    for hwmon in $gpu/hwmon/hwmon*; do
      [ -f "$hwmon/temp1_input" ] && TEMP="$(($(cat $hwmon/temp1_input) / 1000))°C"
    done
    if [ -n "$VRAM_TOTAL" ] && [ "$VRAM_TOTAL" -gt 0 ] 2>/dev/null; then
      VRAM_USED_GB=$(${pkgs.gawk}/bin/awk "BEGIN {printf \"%.1f\", $VRAM_USED / 1073741824}")
      VRAM_TOTAL_GB=$(${pkgs.gawk}/bin/awk "BEGIN {printf \"%.1f\", $VRAM_TOTAL / 1073741824}")
      echo -e "  ''${WHITE}$CARD''${NC}: $GPU_NAME"
      echo -e "       VRAM: ''${VRAM_USED_GB}G/''${VRAM_TOTAL_GB}G | Temp: $TEMP"
    else
      echo -e "  ''${WHITE}$CARD''${NC}: $GPU_NAME | Temp: $TEMP"
    fi
  done

  # Memory summary
  section "💾 MEMORY"
  free -h | head -2 | tail -1 | ${pkgs.gawk}/bin/awk '{print "  RAM:  Total: " $2 "  Used: " $3 "  Available: " $7}'
  free -h | ${pkgs.gnugrep}/bin/grep Swap | ${pkgs.gawk}/bin/awk '{print "  Swap: Total: " $2 "  Used: " $3 "  Free: " $4}'
  if [ -f /sys/block/zram0/disksize ]; then
    ZRAM_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null)
    ZRAM_GB=$(${pkgs.gawk}/bin/awk "BEGIN {printf \"%.1f\", $ZRAM_SIZE / 1073741824}")
    info "Zram" "''${ZRAM_GB}G"
  fi

  # Storage summary
  section "💿 STORAGE"
  df -h -x tmpfs -x devtmpfs -x efivarfs -x overlay 2>/dev/null | tail -n +2 | \
    ${pkgs.gawk}/bin/awk '{printf "  %-20s %5s used of %5s (%s)\n", $6, $3, $2, $5}'
  for nvme in /sys/class/nvme/nvme*/hwmon*; do
    [ -f "$nvme/temp1_input" ] && info "$(echo $nvme | ${pkgs.gnugrep}/bin/grep -o 'nvme[0-9]')" "$(($(cat $nvme/temp1_input) / 1000))°C"
  done

  # Network summary
  section "🌐 NETWORK"
  ${pkgs.iproute2}/bin/ip -br addr 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v "^lo" | while read iface state addr rest; do
    if [ "$state" = "UP" ]; then
      echo -e "  ''${GREEN}●''${NC} $iface: $addr"
    else
      echo -e "  ''${GRAY}○''${NC} $iface ($state)"
    fi
  done

  # Scheduler summary
  section "⚡ SCHEDULER"
  BUILTIN="Standard"
  if [ -f /proc/sys/kernel/sched_bore ]; then BUILTIN="Bore";
  elif [ -f /proc/sys/kernel/sched_bmq_prio ]; then BUILTIN="BMQ";
  elif [ -f /proc/sys/kernel/sched_pds_yield_type ]; then BUILTIN="PDS";
  fi

  if [ -f /sys/kernel/sched_ext/root/ops ]; then
    SCHED=$(cat /sys/kernel/sched_ext/root/ops 2>/dev/null | xargs)
    if [ -n "$SCHED" ]; then
      echo -e "  ''${GREEN}●''${NC} Active: ''${WHITE}$SCHED''${NC} (via sched_ext)"
      info "Built-in" "$BUILTIN (Standby)"
    else
      info "Active" "$BUILTIN (Native)"
      info "sched_ext" "Available (None loaded)"
    fi
  else
    info "Active" "$BUILTIN (Native)"
    info "sched_ext" "Not available"
  fi

  # Display summary
  section "🖥️  DISPLAY"
  # Try to get session info, fallback to loginctl for sudo
  SESSION_TYPE="''${XDG_SESSION_TYPE:-}"
  SESSION_DESKTOP="''${XDG_CURRENT_DESKTOP:-}"
  if [ -z "$SESSION_TYPE" ] && command -v loginctl &>/dev/null; then
     SESSION_ID=$(loginctl session-status | head -n 1 | awk '{print $1}' 2>/dev/null)
     if [ -n "$SESSION_ID" ]; then
       SESSION_TYPE=$(loginctl show-session "$SESSION_ID" -p Type --value 2>/dev/null)
       SESSION_DESKTOP=$(loginctl show-session "$SESSION_ID" -p Desktop --value 2>/dev/null)
     fi
  fi
  info "Session" "''${SESSION_TYPE:-unknown} / ''${SESSION_DESKTOP:-unknown}"
  if [ "$SESSION_TYPE" = "wayland" ]; then
    if command -v ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor &>/dev/null; then
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --outputs 2>/dev/null | ${pkgs.gnused}/bin/sed 's/\x1b\[[0-9;]*m//g' | while read line; do
        if echo "$line" | ${pkgs.gnugrep}/bin/grep -q "^Output:"; then
          OUTPUT_NAME=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $3}')
        fi
        if echo "$line" | ${pkgs.gnugrep}/bin/grep -q "Modes:"; then
          ACTIVE_MODE=$(echo "$line" | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+x[0-9]+@[0-9.]+\*' | ${pkgs.gnused}/bin/sed 's/\*//' | head -1)
          if [ -n "$ACTIVE_MODE" ] && [ -n "$OUTPUT_NAME" ]; then
            RES=$(echo "$ACTIVE_MODE" | cut -d@ -f1)
            RATE=$(echo "$ACTIVE_MODE" | cut -d@ -f2 | cut -d. -f1)
            echo -e "  ''${GREEN}●''${NC} $OUTPUT_NAME: ''${WHITE}$RES''${NC} @ ''${CYAN}''${RATE}Hz''${NC}"
          fi
        fi
      done
    elif command -v ${pkgs.wlr-randr}/bin/wlr-randr &>/dev/null; then
      ${pkgs.wlr-randr}/bin/wlr-randr 2>/dev/null
    fi
  fi

  # Kernel summary
  section "🐧 KERNEL"
  info "Version" "$(uname -r)"
  info "Boot time" "$(systemd-analyze 2>/dev/null | head -1 | ${pkgs.gnused}/bin/sed 's/Startup finished in //')"

  # Services summary
  section "🔌 SERVICES"
  subsection "System (running)"
  systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
    ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.gnused}/bin/sed 's/.service$//' | \
    ${pkgs.gnugrep}/bin/grep -E '^(NetworkManager|bluetooth|sddm|lact|scx|docker|libvirtd|sshd|tailscale|syncthing|cups|pipewire|wireplumber|lactd)$' | \
    sort | while read svc; do echo -e "  ''${GREEN}●''${NC} $svc"; done
  TOTAL=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)
  echo -e "  ''${GRAY}($TOTAL total running)''${NC}"

  FAILED_SYS=$(systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | wc -l)
  if [ "$FAILED_SYS" -gt 0 ]; then
    subsection "Failed"
    systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1}' | while read svc; do
      echo -e "  ''${RED}✗''${NC} $svc"
    done
  fi

  # Errors summary
  section "⚠️  ERRORS"
  DMESG_ERR=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | wc -l)
  JOURNAL_ERR=$(journalctl -b -p err --no-pager 2>/dev/null | wc -l)
  if [ "$DMESG_ERR" -gt 0 ] || [ "$JOURNAL_ERR" -gt 0 ]; then
    echo -e "  ''${YELLOW}⚠''${NC} dmesg: $DMESG_ERR errors | journal: $JOURNAL_ERR errors"
    subsection "Recent Errors (top 5)"
    journalctl -b -p err --no-pager -o cat 2>/dev/null | \
      ${pkgs.gnused}/bin/sed 's/\[.*\]//g' | sort | uniq -c | sort -rn | head -5 | \
      while read count msg; do
        short_msg=$(echo "$msg" | cut -c1-60)
        [ ''${#msg} -gt 60 ] && short_msg="$short_msg..."
        echo -e "  ''${YELLOW}$count×''${NC} $short_msg"
      done
    echo -e "  ''${GRAY}Run sysdiag --errors for details''${NC}"
  else
    echo -e "  ''${GREEN}✓''${NC} No errors found"
  fi

  # Top processes
  section "📈 TOP PROCESSES"
  subsection "By CPU"
  ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | \
    ${pkgs.gawk}/bin/awk '{printf "  %5s%% %5s  %s\n", $3, $4"%", $11}' | head -5
  subsection "By Memory"
  ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 | \
    ${pkgs.gawk}/bin/awk '{printf "  %5s%% %5s  %s\n", $4, $6/1024"M", $11}' | head -5

  # USB devices
  section "🔌 USB DEVICES"
  ${pkgs.usbutils}/bin/lsusb 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v "root hub" | while read line; do
    name=$(echo "$line" | ${pkgs.gnused}/bin/sed 's/.*ID [0-9a-f:]\\+ //')
    id=$(echo "$line" | ${pkgs.gnugrep}/bin/grep -oE 'ID [0-9a-f:]+' | ${pkgs.gnused}/bin/sed 's/ID //')
    echo -e "  ''${GRAY}$id''${NC} $name"
  done

  if $HAS_BATTERY; then
    section "🔋 POWER"
    if command -v ${pkgs.upower}/bin/upower &>/dev/null; then
      ${pkgs.upower}/bin/upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E "state|percentage" | head -2
    fi
  fi

  echo ""
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
  echo -e "  ''${GREEN}✓ Overview complete''${NC} | Run ''${WHITE}sysdiag --help''${NC} for full options"
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════
case "''${1:-}" in
  --cpu)       show_cpu ;;
  --gpu)       show_gpu ;;
  --memory)    show_memory ;;
  --storage)   show_storage ;;
  --network)   show_network ;;
  --services)  show_services ;;
  --kernel)    show_kernel ;;
  --scheduler) show_scheduler ;;
  --display)   show_display ;;
  --errors)    show_errors ;;
  --all)
    show_cpu; show_gpu; show_memory; show_storage; show_network
    show_services; show_kernel; show_scheduler; show_display; show_errors
    ;;
  --help|-h)   show_help ;;
  "")          show_overview ;;
  *)           echo "Unknown option: $1"; show_help; exit 1 ;;
esac
''
