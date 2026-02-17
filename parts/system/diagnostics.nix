{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.system.diagnostics;
  
  # Comprehensive system diagnostics script with subcommands
  sysdiag = pkgs.writeShellScriptBin "sysdiag" ''
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
    grep -qi "AMD" /proc/cpuinfo && HAS_AMD_CPU=true
    grep -qi "Intel" /proc/cpuinfo && HAS_INTEL_CPU=true
    ${pkgs.pciutils}/bin/lspci 2>/dev/null | grep -qi "VGA.*AMD\|Display.*AMD\|3D.*AMD" && HAS_AMD_GPU=true
    ${pkgs.pciutils}/bin/lspci 2>/dev/null | grep -qi "VGA.*NVIDIA\|3D.*NVIDIA" && HAS_NVIDIA_GPU=true
    ${pkgs.pciutils}/bin/lspci 2>/dev/null | grep -qi "VGA.*Intel" && HAS_INTEL_GPU=true
    [ -d /sys/class/power_supply/BAT0 ] && HAS_BATTERY=true
    
    # ═══════════════════════════════════════════════════════════════════════════
    # INDIVIDUAL DIAGNOSTIC FUNCTIONS (FULL OUTPUT)
    # ═══════════════════════════════════════════════════════════════════════════
    
    show_cpu() {
      section "🔧 CPU INFORMATION (FULL)"
      
      subsection "Processor"
      cat /proc/cpuinfo | grep -E "model name|cpu MHz|cache size|cpu cores|siblings" | head -10
      
      subsection "CPU Topology"
      lscpu 2>/dev/null || cat /proc/cpuinfo | head -30
      
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
      sensors 2>/dev/null || echo "  lm_sensors not available"
    }
    
    show_gpu() {
      section "🎮 GPU INFORMATION (FULL)"
      
      subsection "All GPUs (lspci)"
      ${pkgs.pciutils}/bin/lspci -v 2>/dev/null | grep -A 20 "VGA\|3D\|Display"
      
      if $HAS_AMD_GPU; then
        subsection "AMD GPU Sysfs"
        for gpu in /sys/class/drm/card*/device; do
          [ -d "$gpu" ] || continue
          echo -e "  ''${WHITE}$(dirname $gpu | xargs basename)''${NC}"
          for f in gpu_busy_percent mem_info_vram_used mem_info_vram_total power_dpm_state power_dpm_force_performance_level pp_power_profile_mode current_link_speed current_link_width; do
            [ -f "$gpu/$f" ] && info "  $f" "$(cat $gpu/$f 2>/dev/null | head -1)"
          done
          # Temperature
          for hwmon in $gpu/hwmon/hwmon*; do
            [ -f "$hwmon/temp1_input" ] && info "  temp" "$(($(cat $hwmon/temp1_input) / 1000))°C"
          done
        done
        
        subsection "RADV/Mesa Environment"
        env | grep -E "RADV|MESA|AMD|VK_" | sort || echo "  No RADV env vars set"
        
        if command -v rocm-smi &>/dev/null; then
          subsection "rocm-smi"
          rocm-smi 2>/dev/null
        fi
        
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
      vulkaninfo 2>/dev/null || echo "  vulkaninfo not available"
      
      subsection "OpenGL (Full)"
      glxinfo 2>/dev/null | head -50 || echo "  glxinfo not available"
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
      lsblk -f
      
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
        sudo smartctl -a "$disk" 2>/dev/null | head -40
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
      ip addr
      
      subsection "Routes"
      ip route
      
      subsection "DNS"
      cat /etc/resolv.conf
      
      subsection "Listening Ports"
      ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null
      
      subsection "Active Connections"
      ss -tnp 2>/dev/null | head -20
      
      if command -v ethtool &>/dev/null; then
        subsection "Ethernet Details"
        for iface in $(ip -o link | awk -F': ' '/: e/{print $2}'); do
          echo -e "  ''${WHITE}$iface''${NC}"
          ethtool "$iface" 2>/dev/null | head -20
        done
      fi
    }
    
    show_services() {
      section "� SERVICES (FULL)"
      
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
      lsmod | sort
      
      subsection "Kernel Messages (last 100)"
      dmesg | tail -100
    }
    
    show_scheduler() {
      section "⚡ SCHEDULER (FULL)"
      
      subsection "Kernel Scheduler"
      if [ -d /sys/kernel/sched_ext ]; then
        for f in /sys/kernel/sched_ext/*; do
          [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
        done
        for f in /sys/kernel/sched_ext/root/*; do
          [ -f "$f" ] && info "root/$(basename $f)" "$(cat $f 2>/dev/null)"
        done
      else
        info "sched_ext" "Not available"
      fi
      
      subsection "Running scx Processes"
      pgrep -a 'scx_' 2>/dev/null || echo "  No scx scheduler running"
      
      subsection "scx Service Status"
      systemctl status scx.service 2>/dev/null || echo "  scx.service not found"
      
      subsection "CPU Scheduler Info"
      for cpu in /sys/devices/system/cpu/cpu0; do
        for f in $cpu/topology/*; do
          [ -f "$f" ] && info "$(basename $f)" "$(cat $f 2>/dev/null)"
        done
      done
    }
    
    show_errors() {
      section "⚠️ ERRORS (FULL)"
      
      subsection "dmesg Errors (All)"
      dmesg --level=err,crit,alert,emerg 2>/dev/null || dmesg | grep -iE "error|fail|crit"
      
      subsection "Journal Errors (This Boot)"
      journalctl -b -p err --no-pager
    }
    
    show_display() {
      section "🖥️ DISPLAY (FULL)"
      
      subsection "Session Info"
      info "XDG_SESSION_TYPE" "''${XDG_SESSION_TYPE:-unknown}"
      info "XDG_CURRENT_DESKTOP" "''${XDG_CURRENT_DESKTOP:-unknown}"
      info "WAYLAND_DISPLAY" "''${WAYLAND_DISPLAY:-not set}"
      info "DISPLAY" "''${DISPLAY:-not set}"
      
      subsection "DRM Devices"
      for card in /sys/class/drm/card*; do
        [ -d "$card" ] && info "$(basename $card)" "$(cat $card/device/driver/module/name 2>/dev/null || echo 'unknown')"
      done
      
      subsection "Monitor Info"
      if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        wlr-randr 2>/dev/null || kscreen-doctor --outputs 2>/dev/null || echo "  No Wayland monitor tool available"
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
      # Header
      echo -e "''${MAGENTA}"
      echo "  ╔═══════════════════════════════════════════════════════════════════════╗"
      echo "  ║                    🔍 NIXOS SYSTEM DIAGNOSTICS                        ║"
      echo "  ╚═══════════════════════════════════════════════════════════════════════╝"
      echo -e "''${NC}"
      
      # Quick overview
      section "📊 SYSTEM OVERVIEW"
      fastfetch --logo none 2>/dev/null || { info "Hostname" "$(hostname)"; info "Kernel" "$(uname -r)"; }
      
      # CPU summary
      section "🔧 CPU"
      info "Model" "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
      info "Cores/Threads" "$(grep -c processor /proc/cpuinfo)"
      info "Governor" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
      if $HAS_AMD_CPU && [ -f /sys/devices/system/cpu/amd_pstate/status ]; then
        info "P-State" "$(cat /sys/devices/system/cpu/amd_pstate/status)"
        [ -f /sys/devices/system/cpu/amd_pstate/prefcore ] && info "Prefcore" "$(cat /sys/devices/system/cpu/amd_pstate/prefcore 2>/dev/null)"
      fi
      # Show current frequency range
      MAX_FREQ=0; MIN_FREQ=999999
      for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -f "$cpu" ] || continue
        FREQ=$(($(cat $cpu) / 1000))
        [ $FREQ -gt $MAX_FREQ ] && MAX_FREQ=$FREQ
        [ $FREQ -lt $MIN_FREQ ] && MIN_FREQ=$FREQ
      done
      info "Frequency" "$MIN_FREQ - $MAX_FREQ MHz"
      # CPU temps
      sensors 2>/dev/null | grep -E "Tctl|Tdie|Package" | head -2 | while read l; do echo "  $l"; done
      
      # GPU summary
      section "🎮 GPU"
      # Show GPU names with VRAM and temps inline
      for gpu in /sys/class/drm/card*/device; do
        [ -d "$gpu" ] || continue
        CARD=$(dirname $gpu | xargs basename)
        PCI_ADDR=$(basename $(readlink -f $gpu) 2>/dev/null)
        GPU_NAME=$(${pkgs.pciutils}/bin/lspci -s "$PCI_ADDR" 2>/dev/null | sed 's/.*: //' | cut -c1-50)
        VRAM_USED=$(cat $gpu/mem_info_vram_used 2>/dev/null)
        VRAM_TOTAL=$(cat $gpu/mem_info_vram_total 2>/dev/null)
        TEMP="N/A"
        for hwmon in $gpu/hwmon/hwmon*; do
          [ -f "$hwmon/temp1_input" ] && TEMP="$(($(cat $hwmon/temp1_input) / 1000))°C"
        done
        if [ -n "$VRAM_TOTAL" ] && [ "$VRAM_TOTAL" -gt 0 ]; then
          VRAM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $VRAM_USED / 1073741824}")
          VRAM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $VRAM_TOTAL / 1073741824}")
          echo -e "  ''${WHITE}$CARD''${NC}: $GPU_NAME"
          echo -e "       VRAM: ''${VRAM_USED_GB}G/''${VRAM_TOTAL_GB}G | Temp: $TEMP"
        else
          echo -e "  ''${WHITE}$CARD''${NC}: $GPU_NAME | Temp: $TEMP"
        fi
      done
      
      # Memory summary
      section "💾 MEMORY"
      free -h | head -2 | tail -1 | awk '{print "  RAM:  Total: " $2 "  Used: " $3 "  Available: " $7}'
      free -h | grep Swap | awk '{print "  Swap: Total: " $2 "  Used: " $3 "  Free: " $4}'
      # Zram info
      if [ -f /sys/block/zram0/disksize ]; then
        ZRAM_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null)
        ZRAM_GB=$(awk "BEGIN {printf \"%.1f\", $ZRAM_SIZE / 1073741824}")
        info "Zram" "''${ZRAM_GB}G"
      fi
      
      # Storage summary
      section "💿 STORAGE"
      # Show all real mounts (exclude temp/virtual filesystems)
      df -h -x tmpfs -x devtmpfs -x efivarfs -x overlay 2>/dev/null | tail -n +2 | \
        awk '{printf "  %-20s %5s used of %5s (%s)\n", $6, $3, $2, $5}'
      # NVMe temps
      for nvme in /sys/class/nvme/nvme*/hwmon*; do
        [ -f "$nvme/temp1_input" ] && info "$(echo $nvme | grep -o 'nvme[0-9]')" "$(($(cat $nvme/temp1_input) / 1000))°C"
      done
      # Disk I/O stats (read/write since boot)
      subsection "Disk I/O"
      for disk in /sys/block/nvme* /sys/block/sd*; do
        [ -d "$disk" ] || continue
        NAME=$(basename $disk)
        STAT=$(cat $disk/stat 2>/dev/null)
        [ -z "$STAT" ] && continue
        # Sectors are 512 bytes; stat fields: read_ios read_sectors write_ios write_sectors
        READ_SECTORS=$(echo $STAT | awk '{print $3}')
        WRITE_SECTORS=$(echo $STAT | awk '{print $7}')
        READ_GB=$(awk "BEGIN {printf \"%.1f\", $READ_SECTORS * 512 / 1073741824}")
        WRITE_GB=$(awk "BEGIN {printf \"%.1f\", $WRITE_SECTORS * 512 / 1073741824}")
        echo -e "  $NAME: Read: ''${READ_GB}G | Write: ''${WRITE_GB}G"
      done
      
      # Network summary
      section "🌐 NETWORK"
      ip -br addr 2>/dev/null | grep -v "^lo" | while read iface state addr rest; do
        if [ "$state" = "UP" ]; then
          echo -e "  ''${GREEN}●''${NC} $iface: $addr"
        else
          echo -e "  ''${GRAY}○''${NC} $iface ($state)"
        fi
      done
      
      # Scheduler summary
      section "⚡ SCHEDULER"
      if [ -f /sys/kernel/sched_ext/root/ops ]; then
        SCHED=$(cat /sys/kernel/sched_ext/root/ops 2>/dev/null | xargs)
        if [ -n "$SCHED" ]; then
          echo -e "  ''${GREEN}●''${NC} sched_ext: ''${WHITE}$SCHED''${NC}"
        else
          info "sched_ext" "No scheduler loaded (using CFS)"
        fi
      else
        info "sched_ext" "Not available"
      fi
      
      # Display summary
      section "🖥️ DISPLAY"
      info "Session" "''${XDG_SESSION_TYPE:-unknown} / ''${XDG_CURRENT_DESKTOP:-unknown}"
      # Show monitor details
      if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        # For KDE Wayland, use kscreen-doctor
        if command -v kscreen-doctor &>/dev/null; then
          kscreen-doctor --outputs 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | while read line; do
            # Match "Output: N NAME UUID"
            if echo "$line" | grep -q "^Output:"; then
              OUTPUT_NAME=$(echo "$line" | awk '{print $3}')
            fi
            # Match modes line, find the active one (marked with *)
            if echo "$line" | grep -q "Modes:"; then
              ACTIVE_MODE=$(echo "$line" | grep -oE '[0-9]+x[0-9]+@[0-9.]+\*' | sed 's/\*//' | head -1)
              if [ -n "$ACTIVE_MODE" ] && [ -n "$OUTPUT_NAME" ]; then
                RES=$(echo "$ACTIVE_MODE" | cut -d@ -f1)
                RATE=$(echo "$ACTIVE_MODE" | cut -d@ -f2 | cut -d. -f1)
                echo -e "  ''${GREEN}●''${NC} $OUTPUT_NAME: ''${WHITE}$RES''${NC} @ ''${CYAN}''${RATE}Hz''${NC}"
              fi
            fi
          done
        # Fallback for wlroots
        elif command -v wlr-randr &>/dev/null; then
          wlr-randr 2>/dev/null | grep -E "^[A-Z]|current" | paste - - | \
            awk '{print "  ● " $1 ": " $4 " @ " $6}'
        fi
      else
        # X11
        xrandr 2>/dev/null | grep " connected" | while read line; do
          NAME=$(echo "$line" | awk '{print $1}')
          RES=$(echo "$line" | grep -oE '[0-9]+x[0-9]+\+' | sed 's/+//' | head -1)
          echo "  ● $NAME: $RES"
        done
      fi
      
      # Kernel summary
      section "🐧 KERNEL"
      info "Version" "$(uname -r)"
      info "Boot time" "$(systemd-analyze 2>/dev/null | head -1 | sed 's/Startup finished in //')"
      
      # Services summary
      section "🔌 SERVICES"
      subsection "System (running)"
      systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
        awk '{print $1}' | sed 's/.service$//' | \
        grep -E '^(NetworkManager|bluetooth|sddm|lact|scx|docker|libvirtd|sshd|tailscale|syncthing|cups)$' | \
        sort | while read svc; do echo -e "  ''${GREEN}●''${NC} $svc"; done
      TOTAL=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)
      echo -e "  ''${GRAY}($TOTAL total running)''${NC}"
      
      subsection "User (running)"  
      systemctl --user list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
        awk '{print $1}' | sed 's/.service$//' | \
        grep -E '^(pipewire|pipewire-pulse|wireplumber|xdg-desktop-portal)' | \
        while read svc; do echo -e "  ''${GREEN}●''${NC} $svc"; done
      
      # Failed services
      FAILED_SYS=$(systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | wc -l)
      if [ "$FAILED_SYS" -gt 0 ]; then
        subsection "Failed"
        systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null | awk '{print $1}' | while read svc; do
          echo -e "  ''${RED}✗''${NC} $svc"
        done
      fi
      
      # Errors summary
      section "⚠️ ERRORS"
      DMESG_ERR=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | wc -l)
      JOURNAL_ERR=$(journalctl -b -p err --no-pager 2>/dev/null | wc -l)
      if [ "$DMESG_ERR" -gt 0 ] || [ "$JOURNAL_ERR" -gt 0 ]; then
        echo -e "  ''${YELLOW}⚠''${NC} dmesg: $DMESG_ERR errors | journal: $JOURNAL_ERR errors"
        # Show top 5 unique error messages
        subsection "Recent Errors (top 5)"
        journalctl -b -p err --no-pager -o cat 2>/dev/null | \
          sed 's/\[.*\]//g' | \
          sort | uniq -c | sort -rn | head -5 | \
          while read count msg; do
            # Truncate long messages
            short_msg=$(echo "$msg" | cut -c1-60)
            [ ''${#msg} -gt 60 ] && short_msg="$short_msg..."
            echo -e "  ''${YELLOW}$count×''${NC} $short_msg"
          done
        echo -e "  ''${GRAY}Run sysdiag --errors for details''${NC}"
      else
        echo -e "  ''${GREEN}✓''${NC} No errors found"
      fi
      
      # Top Processes
      section "📈 TOP PROCESSES"
      subsection "By CPU"
      ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | \
        awk '{printf "  %5s%% %5s  %s\n", $3, $4"%", $11}' | head -5
      subsection "By Memory"
      ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 | \
        awk '{printf "  %5s%% %5s  %s\n", $4, $6/1024"M", $11}' | head -5
      
      # USB Devices
      section "🔌 USB DEVICES"
      ${pkgs.usbutils}/bin/lsusb 2>/dev/null | grep -v "root hub" | while read line; do
        # Extract bus, device, and name
        name=$(echo "$line" | sed 's/.*ID [0-9a-f:]\+ //')
        id=$(echo "$line" | grep -oE 'ID [0-9a-f:]+' | sed 's/ID //')
        echo -e "  ''${GRAY}$id''${NC} $name"
      done
      
      # Power (if laptop)
      if $HAS_BATTERY; then
        section "🔋 POWER"
        if command -v upower &>/dev/null; then
          BATTERY=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep -E "state|percentage" | head -2)
          echo "  $BATTERY"
        fi
      fi
      
      # Footer
      echo ""
      echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
      echo -e "  ''${GREEN}✓ Overview complete''${NC} | Run ''${WHITE}sysdiag --help''${NC} for full options"
      echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
    }
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MAIN
    # ═══════════════════════════════════════════════════════════════════════════
    case "''${1:-}" in
      --cpu)      show_cpu ;;
      --gpu)      show_gpu ;;
      --memory)   show_memory ;;
      --storage)  show_storage ;;
      --network)  show_network ;;
      --services) show_services ;;
      --kernel)   show_kernel ;;
      --scheduler) show_scheduler ;;
      --display)  show_display ;;
      --errors)   show_errors ;;
      --all)
        show_cpu
        show_gpu
        show_memory
        show_storage
        show_network
        show_services
        show_kernel
        show_scheduler
        show_display
        show_errors
        ;;
      --help|-h)  show_help ;;
      "")         show_overview ;;
      *)          echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
  '';

in {
  options.myModules.system.diagnostics.enable = lib.mkEnableOption "System diagnostics command (sysdiag)";
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      sysdiag
      
      # Hardware detection
      pkgs.pciutils         # lspci
      pkgs.usbutils         # lsusb
      pkgs.lm_sensors       # sensors
      pkgs.smartmontools    # smartctl
      
      # Graphics
      pkgs.vulkan-tools     # vulkaninfo
      pkgs.mesa-demos       # glxinfo
      
      # System info
      pkgs.fastfetch        # system overview
      pkgs.util-linux       # lscpu, lsblk
      pkgs.iproute2         # ip, ss
      pkgs.ethtool          # ethtool
      
      # Display detection
      pkgs.wlr-randr                # wlr-randr (wlroots Wayland)
      pkgs.kdePackages.libkscreen   # kscreen-doctor (KDE Plasma 6 Wayland)
      
      # Power management (laptops)
      pkgs.upower           # upower
    ];
  };
}