{ inputs, ... }: {
  flake.nixosModules.cachyos-settings = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.cachyos.settings;

      # PCI latency script from CachyOS
      # Sets sound card PCI latency to 80 cycles for reduced audio latency
      # Resets all other devices to 20 cycles to prevent gaps
      pciLatencyScript = pkgs.writeShellScript "pci-latency" ''
        if [ "$(id -u)" -ne 0 ]; then
          echo "Error: This script must be run with root privileges." >&2
          exit 1
        fi
        ${pkgs.pciutils}/bin/setpci -v -s '*:*' latency_timer=20
        ${pkgs.pciutils}/bin/setpci -v -s '0:0' latency_timer=0
        ${pkgs.pciutils}/bin/setpci -v -d '*:*:04xx' latency_timer=80
      '';
    in {
      options.myModules.cachyos.settings = {
        enable = lib.mkEnableOption "CachyOS system optimizations (upstream-matched settings)";

        ioSchedulers = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apply I/O scheduler udev rules (bfq=HDD, mq-deadline=SSD, none=NVMe)";
        };

        pciLatency = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable PCI latency service for audio latency reduction";
        };

        audioPowerSave = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Disable snd-hda-intel power saving on AC to prevent audio crackling";
        };

        hdparmTuning = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apply hdparm settings to rotational disks (-B 254 -S 0)";
        };

        sataALPM = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Set SATA link power management to max_performance";
        };

        ntsync = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Load ntsync kernel module (Wine/Proton NT synchronization primitives)";
        };

        amdgpuGcnCompat = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Force amdgpu driver for GCN 1.0+ (SI) and GCN 2.x (CIK) GPUs. Not needed for RDNA+";
        };

        thp = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Configure THP defrag (defer+madvise) and khugepaged shrinker (kernel 6.12+)";
        };

        nvidiaTuning = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Apply NVIDIA GPU modprobe/udev optimizations (PAT, runtime PM, power management). Only for NVIDIA GPUs";
        };
      };

      config = lib.mkIf cfg.enable {

        # ====================================================================
        # Sysctl — Kernel Runtime Configuration
        # Source: usr/lib/sysctl.d/70-cachyos-settings.conf
        # ====================================================================
        boot.kernel.sysctl = {
          # Memory & I/O Management
          # Base swappiness for non-ZRAM (overridden to 150 by ZRAM udev rule at runtime)
          "vm.swappiness" = 100;
          # Lower VFS cache pressure to keep directory/inode caches longer
          "vm.vfs_cache_pressure" = 50;
          # Process starts writing dirty data at 256MB
          "vm.dirty_bytes" = 268435456;
          # Background flusher starts at 64MB
          "vm.dirty_background_bytes" = 67108864;
          # Flusher wakeup interval: 15 seconds
          "vm.dirty_writeback_centisecs" = 1500;
          # Disable swap readahead clustering (optimal for ZRAM/SSD)
          "vm.page-cluster" = 0;

          # System Stability & Security
          # Disable NMI watchdog (performance + power saving)
          "kernel.nmi_watchdog" = 0;
          # Allow unprivileged user namespaces (containers, sandboxing)
          "kernel.unprivileged_userns_clone" = 1;
          # Hide kernel messages from console
          "kernel.printk" = "3 3 3 3";
          # Restrict kernel pointer exposure in /proc
          "kernel.kptr_restrict" = 2;

          # Network
          # Increase network device backlog queue
          "net.core.netdev_max_backlog" = 4096;
          # Use CAKE qdisc for better latency and fairness
          "net.core.default_qdisc" = "cake";

          # Filesystem
          # Increase maximum open file handles
          "fs.file-max" = 2097152;

          # Gaming / Proton
          # Required by many Steam/Proton games — some crash without this
          "vm.max_map_count" = 2147483642;

          # Desktop/Gaming Performance
          # Disable proactive memory compaction — reduces latency spikes on large RAM (64GB+)
          "vm.compaction_proactiveness" = 0;
          # Disable CFS autogroups — let sched_ext handle scheduling
          "kernel.sched_autogroup_enabled" = 0;

          # TCP Performance (gaming + downloads)
          # BBR congestion control — better throughput and lower latency than cubic
          "net.ipv4.tcp_congestion_control" = "bbr";
          # Enable TCP Fast Open for client + server
          "net.ipv4.tcp_fastopen" = 3;
          # Increase TCP buffer sizes for high-bandwidth connections
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_max" = 16777216;
        };

        # ====================================================================
        # ZRAM Swap Configuration
        # Source: usr/lib/systemd/zram-generator.conf
        # ====================================================================
        zramSwap = {
          enable = true;
          algorithm = "zstd";
          memoryPercent = 100;
          priority = 100;
        };

        # ====================================================================
        # Udev Rules — Device Event Automation
        # ====================================================================
        services.udev.extraRules = lib.concatStringsSep "\n" (lib.filter (s: s != "") [

          # --- I/O Schedulers ---
          # Source: usr/lib/udev/rules.d/60-ioschedulers.rules
          (lib.optionalString cfg.ioSchedulers ''
            # HDD: bfq
            ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
            # SSD: mq-deadline
            ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
            # NVMe: none
            ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
          '')

          # --- ZRAM Swappiness Override ---
          # Source: usr/lib/udev/rules.d/30-zram.rules
          # When ZRAM is active, override swappiness to 150 (prefer compressing anon pages)
          # and disable zswap to prevent conflicts
          ''
            ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", RUN+="${pkgs.bash}/bin/bash -c 'echo N > /sys/module/zswap/parameters/enabled'"
          ''

          # --- Audio Power Management ---
          # Source: usr/lib/udev/rules.d/20-audio-pm.rules
          (lib.optionalString cfg.audioPowerSave ''
            ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", RUN+="${pkgs.bash}/bin/bash -c 'touch /run/udev/snd-hda-intel-powersave; [[ $$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) != \"Discharging\" ]] && echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave && echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
            SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", RUN+="${pkgs.bash}/bin/bash -c 'echo $$(cat /run/udev/snd-hda-intel-powersave 2>/dev/null || echo 10) > /sys/module/snd_hda_intel/parameters/power_save'"
            SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", RUN+="${pkgs.bash}/bin/bash -c '[[ $$(cat /sys/module/snd_hda_intel/parameters/power_save) != 0 ]] && echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave; echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
          '')

          # --- SATA Active Link Power Management ---
          # Source: usr/lib/udev/rules.d/50-sata.rules
          (lib.optionalString cfg.sataALPM ''
            ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_supported}=="1", ATTR{link_power_management_policy}="max_performance"
          '')

          # --- HDD hdparm Tuning ---
          # Source: usr/lib/udev/rules.d/69-hdparm.rules
          (lib.optionalString cfg.hdparmTuning ''
            ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTRS{id/bus}=="ata", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 0 /dev/%k"
          '')

          # --- Device Permissions (Audio) ---
          # Source: usr/lib/udev/rules.d/40-hpet-permissions.rules
          ''
            KERNEL=="rtc0", GROUP="audio"
            KERNEL=="hpet", GROUP="audio"
          ''

          # --- CPU DMA Latency Permissions ---
          # Source: usr/lib/udev/rules.d/99-cpu-dma-latency.rules
          ''
            DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
          ''

          # --- NVIDIA Runtime Power Management ---
          # Source: usr/lib/udev/rules.d/71-nvidia.rules
          (lib.optionalString cfg.nvidiaTuning ''
            ACTION=="add|bind", SUBSYSTEM=="pci", DRIVERS=="nvidia", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", TEST=="power/control", ATTR{power/control}="auto"
            ACTION=="remove|unbind", SUBSYSTEM=="pci", DRIVERS=="nvidia", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", TEST=="power/control", ATTR{power/control}="on"
          '')
        ]);

        # ====================================================================
        # Modprobe — Kernel Module Parameters
        # ====================================================================

        # Source: usr/lib/modprobe.d/blacklist.conf
        # Blacklist watchdog timers (performance + power saving)
        boot.blacklistedKernelModules = [ "iTCO_wdt" "sp5100_tco" ];

        # Source: usr/lib/modules-load.d/ntsync.conf
        # NT synchronization primitives for Wine/Proton
        boot.kernelModules = lib.optionals cfg.ntsync [ "ntsync" ];

        # Modprobe configuration
        # Source: usr/lib/modprobe.d/amdgpu.conf + nvidia.conf + snd-hda-intel
        boot.extraModprobeConfig = lib.concatStringsSep "\n" (lib.filter (s: s != "") [
          # Force amdgpu for GCN 1.0+ (SI) and GCN 2.x (CIK) GPUs
          (lib.optionalString cfg.amdgpuGcnCompat ''
            options amdgpu si_support=1 cik_support=1
            options radeon si_support=0 cik_support=0
          '')
          # Source: usr/lib/modprobe.d/nvidia.conf
          (lib.optionalString cfg.nvidiaTuning ''
            options nvidia NVreg_UsePageAttributeTable=1 NVreg_InitializeSystemMemoryAllocations=0 NVreg_RegistryDwords=RmEnableAggressiveVblank=1 NVreg_DynamicPowerManagement=0x02 NVreg_EnableS0ixPowerManagement=1
          '')
          # Disable snd-hda-intel power saving at module level
          (lib.optionalString cfg.audioPowerSave ''
            options snd-hda-intel power_save=0
          '')
        ]);

        # ====================================================================
        # Systemd — Service & System Management
        # ====================================================================

        # Source: usr/lib/systemd/journald.conf.d/00-journal-size.conf
        services.journald.extraConfig = ''
          SystemMaxUse=50M
        '';

        # Source: usr/lib/systemd/system.conf.d/00-timeout.conf + 10-limits.conf
        systemd.settings.Manager = {
          DefaultTimeoutStartSec = "15s";
          DefaultTimeoutStopSec = "10s";
          DefaultLimitNOFILE = "2048:2097152";
        };

        # Source: usr/lib/systemd/user.conf.d/10-limits.conf
        environment.etc."systemd/user.conf.d/10-cachyos-limits.conf".text = ''
          [Manager]
          DefaultLimitNOFILE=1024:1048576
        '';

        # Source: usr/lib/systemd/system/user@.service.d/delegate.conf
        # Delegate cgroup controllers to user services
        systemd.services."user@" = {
          overrideStrategy = "asDropin";
          serviceConfig.Delegate = "cpu cpuset io memory pids";
        };

        # Source: usr/lib/systemd/system/rtkit-daemon.service.d/override.conf
        systemd.services.rtkit-daemon = {
          overrideStrategy = "asDropin";
          serviceConfig.LogLevelMax = "info";
        };

        # Source: usr/lib/systemd/system/pci-latency.service
        systemd.services.pci-latency = lib.mkIf cfg.pciLatency {
          description = "Adjust latency timers for PCI peripherals";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pciLatencyScript}";
          };
        };

        # Source: usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf
        services.timesyncd = {
          enable = lib.mkDefault true;
          servers = [ "time.cloudflare.com" ];
          fallbackServers = [
            "time.google.com"
            "0.nixos.pool.ntp.org"
            "1.nixos.pool.ntp.org"
            "2.nixos.pool.ntp.org"
            "3.nixos.pool.ntp.org"
          ];
        };

        # ====================================================================
        # Tmpfiles — THP & Coredump Management
        # ====================================================================
        systemd.tmpfiles.rules = lib.concatLists [
          # Source: usr/lib/tmpfiles.d/thp.conf
          # Improve performance for tcmalloc-using applications
          (lib.optionals cfg.thp [
            "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
          ])

          # Source: usr/lib/tmpfiles.d/thp-shrinker.conf
          # THP Shrinker (kernel 6.12+): split THPs with >80% zero pages
          (lib.optionals cfg.thp [
            "w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409"
          ])

          # Source: usr/lib/tmpfiles.d/coredump.conf
          # Clear coredumps older than 3 days
          [ "d /var/lib/systemd/coredump 0755 root root 3d" ]
        ];

        # ====================================================================
        # Security — Audio Limits
        # Source: etc/security/limits.d/20-audio.conf
        # ====================================================================
        security.pam.loginLimits = [
          { domain = "@audio"; type = "-"; item = "rtprio"; value = "99"; }
        ];

        # ====================================================================
        # NetworkManager DNS — use systemd-resolved
        # Source: usr/lib/NetworkManager/conf.d/dns.conf
        # ====================================================================
        networking.networkmanager.dns = lib.mkDefault "systemd-resolved";
        services.resolved.enable = lib.mkDefault true;

        # ====================================================================
        # Debuginfod — CachyOS symbol server
        # Source: etc/debuginfod/cachyos.urls
        # ====================================================================
        environment.variables.DEBUGINFOD_URLS = lib.mkDefault "https://debuginfod.cachyos.org";
      };
    };
}
