# macbook-pro-9-2 — NixOS host config for Apple MacBook Pro 9,2 (i5-3210M, 16 GB).
{
  config,
  pkgs,
  inputs,
  lib,
  site,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./kingston.nix
  ];

  # ============================================================================
  # MyModules Configuration — Exhaustive Reference
  # ============================================================================
  # Every myModules option is listed explicitly, even defaults, so this file
  # serves as a display config showing all available knobs for this host.
  # Options using their module default are marked with # (default).
  # ============================================================================
  myModules = {

    # --------------------------------------------------------------------------
    # Host Identity
    # --------------------------------------------------------------------------
    host = {
      tier = "v2"; # Ivy Bridge i5-3210M — SSE4.2, no AVX2
    };

    # --------------------------------------------------------------------------
    # Primary User
    # --------------------------------------------------------------------------
    # primaryUser = "user"; # (default)

    # --------------------------------------------------------------------------
    # Boot
    # --------------------------------------------------------------------------
    boot = {
      loader = {
        enable = true;
        loader = "refind";
        secureBoot.enable = false; # MacBook Pro 9,2 firmware doesn't support custom keys
        plymouth.enable = true;
        refind = {
          timeout = 10;
          maxGenerations = 10;
          theme = pkgs.refind-theme-minimal;
          hideUI = [
            "hints"
            "arrows"
            "badges"
          ];
          showTools = [
            "shutdown"
            "reboot"
            "firmware"
            "apple_recovery"
          ];
        };
      };
      impermanence.enable = false;
      hibernate = {
        # Kingston A400 (/dev/sdb1) holds a 16 GB LUKS-encrypted swap
        # partition created by scripts/repurpose-kingston.sh after the
        # Samsung migration. Initrd unlocks it via the same passphrase
        # chain as cryptroot (cryptsetup caches the passphrase), wires it
        # as resume device so MBP hibernates cleanly. zram (7.8 G,
        # priority 100) still handles steady-state memory pressure; disk
        # swap (priority 10) mainly carries the hibernate image.
        enable = true;
        swapLuksUuid = "4728138f-08c2-4fa2-a77b-3e12e3c1347c";
        ramSizeGB = 16; # MBP 9,2 has 16 GB physical RAM
      };
    };

    # --------------------------------------------------------------------------
    # Nix
    # --------------------------------------------------------------------------
    nix.nix.enable = true;
    # Offload nix builds to ryzen-9950x3d (16C/32T Zen 5) via SSH.
    # Private key lives in /root/.ssh/remotebuild (generated once with
    # `sudo ssh-keygen -f /root/.ssh/remotebuild -N "" -t ed25519`).
    # Public half is in ryzen's server.authorizedKeys; host-key +
    # IP-fallback trust is handled by the remote-builder module — no
    # bare programs.ssh.knownHosts or networking.hosts entries here.
    nix.remoteBuilder = {
      client = {
        enable = true;
        hostName = "ryzen-9950x3d.local";
        sshUser = "remotebuild";
        sshKey = "/root/.ssh/remotebuild";
        # 9950X3D = 16C/32T. maxJobs=32 + cores=1 fills every SMT thread
        # with a single-threaded compile — fastest for many-small-deriv
        # workloads (typical nix store build).
        maxJobs = 32;
        speedFactor = 20; # Zen 5 16C/32T ~20× i5-3210M 2C/4T compile wall-clock
        # Ryzen's ed25519 host public key (cat /etc/ssh/ssh_host_ed25519_key.pub).
        # Rotates rarely; update here + nrb if ryzen reinstalls.
        inherit (site.hosts.macbook-pro-9-2.ssh.remoteBuilder) hostPublicKey;
        extraHostNames = [
          "ryzen-9950x3d"
          site.network.hosts.ryzen-9950x3d.ip
        ];
        staticIp = site.network.hosts.ryzen-9950x3d.ip;
      };
      server.enable = false; # laptop doesn't serve builds
    };

    # --------------------------------------------------------------------------
    # Users
    # --------------------------------------------------------------------------
    users.enable = true;

    # --------------------------------------------------------------------------
    # Storage
    # --------------------------------------------------------------------------
    storage = {
      filesystems = {
        enable = true;
        enableAll = true; # (default)
        enableLinux = true; # (default)
        enableWindows = true; # (default)
        enableMac = true; # (default)
        enableOptical = true; # (default)
        enableLegacy = false; # (default)
      };
      fstrim.enable = true;
      # btrbk target configured by scripts/repurpose-kingston.sh after
      # Samsung root stable — wires targetPath = /mnt/kingston-backup.
      btrbk.enable = false;
    };

    # --------------------------------------------------------------------------
    # Services
    # --------------------------------------------------------------------------
    services = {
      avahi.enable = true;
      cups = {
        enable = true;
        # No printers on this host, no network printers to discover.
        # cups-browsed otherwise churns subscription leases against cupsd
        # every few hours with Create-Printer-Subscriptions probes that
        # cupsd logs as client-error-bad-request before the retry succeeds.
        browsing = false;
      };
      earlyoom = {
        enable = true;
        # MBP 9,2 has 16 GB RAM + 2-core CPU — a compressed zram pool
        # can keep reported "free memory" above 5 % while swap collapses
        # to 0. Raise memoryThreshold to 10 % so earlyoom fires earlier,
        # before the kernel's emergency OOM takes over abruptly.
        memoryThreshold = 10;
        # Prefer killing processes that are known to re-launch cleanly and
        # are common OOM triggers on this host (nix builds, Claude Code
        # process tree, Code OSS, Chromium renderers). Avoid regex keeps
        # the session alive (kwin, pipewire, etc.).
        preferRegex = "^(nix-daemon|nix|cc1|cc1plus|ld|rustc|node|\\.claude-unwrapp|codium|code|Web Content|Isolated Web|chromium|Chrome|firefox|steam|gamescope)$";
      };
      geoclue.enable = true;
      mullvad = {
        # WiFi-break recovery (2026-04-16):
        # First nrb hit `Failed to set IPv6 address (ENOENT)` because
        # mullvad-daemon was using wg-userspace fallback (kernel WireGuard
        # module wasn't pre-loaded). Daemon auto-locked all traffic.
        # Resolved by Daaboulex/mullvad-vpn-nix@41ba6ce which now loads
        # the wireguard kmod + orders the daemon after systemd-modules-load.
        # `tunnel.ipv6 = false` kept as defense-in-depth: ISP has no IPv6
        # routing anyway, and a future kernel/hardening change that drops
        # the WG kmod would re-trigger the original bug if v6-in-tunnel
        # were enabled. Belt + suspenders.
        enable = true;
        # Personal policy — must stay identical to ryzen-9950x3d/default.nix.
        # Mullvad's `lockdown_mode` IS the kill switch (one field, same thing).
        settings = {
          # ── daemon-level toggles ──
          # Always-on policy: tunnel up at boot, kill switch engaged.
          # Why: IP privacy is only real when tunnel is up. Prior config
          # (autoConnect=false, lockdownMode=false) left a window between
          # boot and manual connect where DNS + apps used the real IP.
          # Kill switch + `lan = true` still lets local subnet devices
          # (printer, phone USB tethering — NOT WiFi tether) work.
          # Escape hatch: `systemctl stop mullvad-daemon` temporarily
          # restores clearnet access if at a captive portal (hotel WiFi).
          autoConnect = true;
          lockdownMode = true; # kill switch ON — no clearnet when tunnel down
          lan = true; # local subnet still reachable (printer, LAN peers)
          betaProgram = false;
          updateDefaultLocation = false;
          # ── DNS blockers — ACTIVE (Mullvad's in-tunnel filter tier) ──
          # Portmaster forwards all DNS to 100.64.0.23 via wg0-mullvad
          # (see security.portmaster.settings."dns/nameservers"), so
          # these block* flags decide which categories Mullvad returns
          # NXDOMAIN for. Two filter layers stack: Portmaster's own
          # filter lists block first, these flags block second.
          dns = {
            mode = "default";
            blockAds = true;
            blockTrackers = true;
            blockMalware = true;
            blockGambling = true;
            blockSocialMedia = false;
            blockAdultContent = false;
          };
          # ── obfuscation (WireGuard censorship circumvention) ──
          obfuscation.mode = "auto";
          # ── multihop ──
          multihop.enable = true;
          # ── API access methods (reach Mullvad servers when direct blocked) ──
          apiAccess = {
            direct = true;
            mullvadBridges = true; # Mullvad bridge relay
            encryptedDnsProxy = true; # DoH path to API
          };
          # ── tunnel options ──
          tunnel = {
            quantumResistant = "on";
            ipv6 = false; # ISP has no IPv6 routing; defense-in-depth vs wg-userspace race recurrence
            daita = {
              enable = true;
              useMultihopIfNecessary = true;
            };
          };
          # ── relay constraints (any = no filter) ──
          relay = {
            ipVersion = "any";
            ownership = "any";
            entryOwnership = "any";
          };
        };
      };
      sunshine.enable = false; # No game streaming from the MacBook
      syncthing = {
        enable = true;
        # Kingston A400 (DRAM-less SATA) + btrfs = metadata storm when the
        # full-folder scan runs at boot. Delay by 120 s so KDE settles first.
        startDelay = 120;
        devices.ryzen-9950x3d.id = site.hosts.ryzen-9950x3d.syncthing.deviceId;
        devices.fcse01.id = site.hosts.fcse01.syncthing.deviceId;
        devices.pixel-9-pro.id = site.hosts.pixel-9-pro.syncthing.deviceId;
        folders = {
          documents = {
            path = "/home/user/Documents";
            devices = [
              "ryzen-9950x3d"
              "fcse01"
              "pixel-9-pro"
            ];
            # 6 h periodic scan (fsWatcher already does real-time updates).
            # Default 1 h thrashes the A400's btrfs metadata on every pass.
            rescanIntervalS = 21600;
          };
          ai-context = {
            path = "/home/user/.ai-context";
            devices = [
              "ryzen-9950x3d"
              "fcse01"
              "pixel-9-pro"
            ];
            ignorePerms = true;
            versioningMaxAge = "1209600";
          };
        };
      };
    };

    # --------------------------------------------------------------------------
    # Security
    # --------------------------------------------------------------------------
    security = {
      hardening = {
        enable = true;
        firejail.enable = false; # Not needed — Portmaster handles app isolation
      };
      ssh = {
        enable = true;
        inherit (site.hosts.macbook-pro-9-2.ssh) trustedKeys;
        fail2banIgnoreIPs = [
          "127.0.0.1/8"
          "::1/128"
          site.network.subnet
        ];
      };
      agenix = {
        enable = true;
        # Secrets declared per-host at runtime (`agenix -e secrets/<name>.age`).
        # .age files gitignored + Syncthing-synced, not in flake tree.
        # Add secrets here after encrypting with `agenix -e`:
        #   secrets.wifi = { };
        #   secrets.github-token = { };
      };
      portmaster = {
        enable = true;
        notifier = true; # (default) — system tray icon
        autostart = true; # Start on boot
        # Mullvad + Portmaster stack. See ryzen-9950x3d/default.nix for
        # the full rationale: `dnsQueryInterception=false` is required
        # to avoid the Mullvad-bootstrap deadlock at boot.
        # See ryzen-9950x3d/default.nix for the rationale on why each of
        # these keys MUST live in forceSettings. UI changes to them will
        # be reverted on next boot.
        forceSettings = {
          "filter/dnsQueryInterception" = false;
          "dns/nameservers" = [
            "dot://dns.mullvad.net?ip=194.242.2.3&name=MullvadAdblockDoT&blockedif=empty"
            "dot://dns.quad9.net?ip=9.9.9.9&name=Quad9&blockedif=empty"
            "dot://dns.quad9.net?ip=149.112.112.112&name=Quad9&blockedif=empty"
            "dot://dns.mullvad.net?ip=194.242.2.2&name=MullvadUnfilteredDoT&blockedif=empty"
          ];
          "dns/noAssignedNameservers" = true;
        };
      };
      # See parts/security/portmaster-mullvad-compat.nix for the full
      # rationale. Required on every host where Portmaster and Mullvad
      # both run, otherwise the tunnel can't bootstrap after a reconnect.
      portmasterMullvadCompat.enable = true;
    };

    # --------------------------------------------------------------------------
    # Hardware
    # --------------------------------------------------------------------------
    hardware = {
      core.enable = true;
      networking = {
        enable = true;
        # openPorts = []; # (default)
        # openPortRanges = []; # (default)
      };
      pipewire = {
        enable = true;
        lowLatency = true;
        quantum = 512; # 10.7ms — good balance for 2C/4T (default 256 is aggressive for this CPU)
      };
      bluetooth = {
        enable = true;
        powerOnBoot = false; # Save power — enable on demand
      };
      graphics = {
        enable = true;
        enable32Bit = true; # (default)
        # AMD GPU: not imported on this host (see flake-module.nix)
        # NVIDIA GPU: not imported on this host (see flake-module.nix)
        # openCL.rusticlDrivers assembled automatically from GPU modules
        mesaGit.enable = false; # Standard mesa is fine for HD4000
      };
      gpuIntel = {
        enable = true;
        kernelParams = {
          enablePsr = false; # PSR causes flickering on MBP 2012
          enableFbc = false; # FBC taints kernel with "Setting dangerous option" and can cause glitches
          enableDc = false; # Display C-states unstable on Ivy Bridge
        };
        openCL = true; # (default) — RustiCL iris driver
      };
      cpuIntel = {
        enable = true;
        pstate = {
          enable = true; # (default)
          # Ivy Bridge has no HWP — intel_pstate "active" just pins max P-state,
          # giving no benefit over the generic cpufreq path. Upstream default
          # since kernel 5.7 for non-HWP CPUs is passive + schedutil.
          # Source: Rafael Wysocki, intel_pstate docs.
          mode = "passive";
        };
        governor = "schedutil"; # passive + schedutil: matches or beats active+performance on non-HWP
        kvm.enable = true; # (default) — virtualization (VT-x)
        updateMicrocode = true; # (default)
        iommu.enable = false; # No VT-d passthrough needed
      };
      # AMD CPU: not imported on this host (see flake-module.nix)
      # performance moved to tuning.performance below
      power = {
        enable = true;
        laptop = true; # Enable TLP for laptop power management
      };
      acpid.enable = true;
      upower.enable = true;
      usbmuxd.enable = true;
      udevAccess = {
        enable = true;
        saleae = true;
        debuggingProbes = true;
      };
    };

    # --------------------------------------------------------------------------
    # Tuning
    # --------------------------------------------------------------------------
    tuning.performance = {
      enable = true;
      governor = "schedutil"; # passive intel_pstate + schedutil (Ivy Bridge has no HWP)
      ananicy = true; # CachyOS process prioritization rules
      irqbalance = true; # IRQ balancing — useful on 2C/4T to spread interrupts
      # sched-ext on MBP — currently in evidence-gathering mode (enabled
      # below) on cachyos-lto 7.0.0. Two known concerns motivate caution:
      # scx#3474 — `scx_cgroup_move_task` WARN fires in kernel/sched/ext.c
      # on 6.19.x; Tejun Heo's ops.cgroup_move() rq-tracking patch landed
      # on LKML 2026-04-10 but hasn't reached xanmod 6.19.12 yet (earliest
      # 6.20). cachyos-lto 7.0.0 may carry the backport — observation
      # protocol below tracks whether it does.
      #
      # Also: scx_lavd's topology optimizations (per-LLC, per-core-type,
      # per-NUMA domains) are minimal on i5-3210M (single-LLC, single-
      # socket, HT-only — no P/E asymmetry, no CCDs). The one genuine
      # benefit here is Core Compaction for battery, and on a 2C/4T chip
      # the BPF+Rust daemon overhead eats into that. Unixbench multi-core
      # context switch drops ~94% under any scx_* vs EEVDF (scx#998),
      # and our workload (claude-code streaming + nix-daemon IPC +
      # Konsole rendering) is context-switch heavy.
      #
      # Evidence-gathering enable (2026-04-24): running scx_lavd on
      # cachyos-lto 7.0.0 to observe real behavior vs the two known
      # regressions documented above (scx#3474 cgroup_move WARN +
      # scx#998 context-switch drop). cachyos-lto 7.0.0 may carry
      # scheduler backports that mainline xanmod 6.19 does not — worth
      # measuring on this hardware before trusting memory conclusions
      # from a different kernel tree.
      #
      # Observation protocol:
      #   1. Check `dmesg | grep -iE 'scx|sched_ext|cgroup_move'` for
      #      new WARNs after session start / logout.
      #   2. Compare `turbostat` output under load (see
      #      diagnostics.turbostat.enable below) vs EEVDF baseline.
      #   3. Watch KDE session for stability — prior 2026-04-16
      #      session kicks were correlated with scx enable.
      #
      # Revert: flip `enable = false` if any of (a) cgroup_move WARN
      # in dmesg, (b) perceptible input regression, (c) session kick.
      scx = {
        enable = true;
        scheduler = "scx_lavd";
      };
    };

    # --------------------------------------------------------------------------
    # Diagnostics
    # --------------------------------------------------------------------------
    diagnostics.turbostat.enable = true; # per-core freq + thermal for libinput-lag investigations

    # --------------------------------------------------------------------------
    # Apple hardware
    # --------------------------------------------------------------------------
    hardware.mbpfan = {
      enable = true;
      lowTemp = 45; # Start ramping fan at 45 C
      highTemp = 65; # High fan speed at 65 C
      maxTemp = 80; # Maximum temperature
      pollingInterval = 1; # Check every second
    };
    hardware.hidApple = {
      fnMode = 1; # MBP 9,2 has inverted fnmode — 1 = media keys default, Fn for F-keys
      swapOptCmd = false; # Keep Cmd as Meta — xkb ctrl:swap_lwin_lctl then maps Meta → Ctrl
    };
    hardware.broadcomWifi.enable = true; # Broadcom BCM4331 via in-tree b43 + b43Firmware_6_30_163_46

    input.libinput = {
      enable = true;
      naturalScrolling = true; # (default)
      tapping = true; # (default) — tap-to-click
    };
    hardware.usbPower.enable = true; # Realtek WiFi adapter power management fix

    # DoT opportunistic on this host only. Nix builds (especially Go modules
    # that fetch from storage.googleapis.com) overlap with Portmaster's
    # resolver chain + Mullvad DoT under the 2-core CPU's load; strict
    # "true" causes intermittent SERVFAIL that kills build fetches. "op"
    # still prefers DoT on :853 and only falls back to plaintext if the
    # DoT session can't complete — the common case remains encrypted.
    hardware.networking.dnsOverTls = "opportunistic";

    # --------------------------------------------------------------------------
    # Kernel
    # --------------------------------------------------------------------------
    boot.kernel = {
      enable = true;
      # xanmod kept on MBP 9,2: CachyOS mainline / -lto / -bore / -rc / -hardened
      # are built for x86-64-v3 (AVX2) since the 2025 v3 bump → will NOT boot on
      # Ivy Bridge. If the user wants CachyOS later, switch to `linux-cachyos-lts`
      # or `linux-cachyos-server` (both still v2-compatible).
      variant = "xanmod";
      channel = "latest"; # (default)
      # mArch defaults to "x86-64-v2" via myModules.host.tier = "v2". No explicit override needed.
      extraParams = [
        "vt.global_cursor_default=0" # Hide kernel text cursor
        "nmi_watchdog=0" # Disable NMI hard lockup detector (frees PMU counter); keeps soft lockup + iTCO_wdt active for hang diagnosis
        "mem_sleep_default=deep" # S3 deep sleep (better battery on suspend)
        "acpi_enforce_resources=lax" # Allow ACPI resource access for sensors
        # i915.fastboot removed — parameter no longer exists in 6.19+, caused interlaced boot glitch
        # i915.semaphores removed in kernel 4.6 — GPU scheduler replaced hardware semaphores
      ];
      cachyos = {
        # cpusched only takes effect when variant is a "cachyos-*" kernel.
        # MBP uses variant = "xanmod" (see above), so this line is inert —
        # xanmod kernel does NOT ship BORE (CONFIG_SCHED_BORE unset). The
        # actually-running scheduler on xanmod is EEVDF (kernel default).
        # Uncomment if you ever switch variant = "cachyos-bore" or similar.
        # cpusched = "bore";
        bbr3 = true; # BBR3 congestion control
        hzTicks = "1000"; # 1000Hz tick rate — snappy desktop
        tickrate = "full"; # Full dynamic ticks — better power saving
        preemptType = "full"; # Full preemption — lowest latency
        ccHarder = true; # Extra compiler optimizations
        hugepage = "always"; # Transparent hugepages for memory performance
      };
    };

    # --------------------------------------------------------------------------
    # Desktop
    # --------------------------------------------------------------------------
    desktop = {
      plasma = {
        enable = true;
        xkbLayout = "us"; # (default)
        xkbVariant = ""; # (default)
        ddcBrightness = false; # (default)
      };
      flatpak.enable = true;
      # No displays module config — laptop uses built-in display only
    };

    # Tools & Programs: sysdiag, iommu, benchmarking, wine migrated to HM modules

    # --------------------------------------------------------------------------
    # CachyOS Settings
    # --------------------------------------------------------------------------
    tuning.cachyos = {
      enable = true;
      zram.enable = true; # (default)
      ioSchedulers.enable = true; # (default)
      audio.enable = true; # (default)
      storage.enable = true; # (default)
      thp.enable = true; # (default)
      systemd.enable = true; # (default)
      timesyncd.enable = true; # (default)
      networkManager.enable = true; # (default)
      ntsync.enable = true; # (default)
      debuginfod.enable = true; # (default)
      coredump.enable = true; # (default)
      nvidia.enable = false; # (default) — no NVIDIA GPU
      amdgpuGcnCompat.enable = false; # Intel GPU, not AMD
    };

    # Gaming: not imported on this host (see flake-module.nix)
    # GoXLR: not imported on this host (see flake-module.nix)
  };

  # ============================================================================
  # System & Localization
  # ============================================================================
  system.stateVersion = "26.05";

  networking.hostName = "macbook-pro-9-2";
  time.timeZone = "Europe/Berlin";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };
  };

  # ============================================================================
  # MacBook Pro 9,2 Hardware Fixes
  # ============================================================================
  hardware.enableRedistributableFirmware = true;

  boot = {
    loader.timeout = lib.mkForce 10;

    # Broadcom BCM4331 WiFi: driver + bus blacklist handled by
    # myModules.hardware.broadcomWifi (parts/hardware/broadcom-wifi.nix).
    # That module uses the b43 (ssb) driver path, so b43 MUST NOT be
    # blacklisted here. bcma is blacklisted by the wifi module (ssb
    # claims the card instead).

    blacklistedKernelModules = [
      "iTCO_wdt" # Watchdog timer — not needed, causes errors
      "lpc_ich" # GPIO resource conflicts with ACPI OpRegion
      "acpi_pad" # Not needed on MacBook
      "mac_hid" # Old Mac HID emulation
      "apple_gmux" # No discrete GPU on MBP 9,2 — gmux probe fails harmlessly but clutters dmesg
      "b43legacy" # BCM4331 is handled by b43 (not b43legacy)
    ];

    kernelParams = [
      # Broadcom / IOMMU fixes
      "intremap=off" # Suppress DMAR-IR firmware bug warnings
      "iommu=soft" # Fix USB 3.0 (xhci_hcd) on Ivy Bridge

      # SATA stability — MBP 9,2 SATA PHY / flex-cable can't hold 6.0 Gbps
      # reliably on 3rd-party SSDs. Symptom: recurring ata2 "interface fatal
      # error" { UnrecovData CommWake Handshk } → btrfs transaction stall →
      # 120s hung-task → journald watchdog timeout → whole-system hang.
      # Two flags MUST be in ONE kernel param (comma-separated); separate
      # `libata.force=` entries on cmdline make the last one override the
      # earlier one (so `noncq` got silently dropped). Try 3.0Gbps first;
      # drop to 1.5Gbps only if errors still appear after deploy.
      "libata.force=3.0Gbps,noncq"

      # SD card reader fix
      "sdhci.debug_quirks2=4" # SDHCI_QUIRK2_NO_1_8_V

      # Security mitigations (SMT-aware, Spectre/Meltdown/MDS)
      "mds=full" # Full MDS mitigation

      # Disable sched autogroup. On a systemd-managed desktop, user sessions
      # are already in their own cgroups; autogroup adds a *second* group
      # layer that can race with cgroup migrations during session teardown.
      # Matches ryzen-9950x3d configuration. Evidence: autogroup override is
      # shadowed by cgroup v2 anyway (sched(7)), so we lose nothing while
      # removing a source of races.
      "noautogroup"

      # i915 HD 4000 Gen 7 — power-save features OFF for input-latency
      # reasons. Aligns with gpuIntel.kernelParams.enablePsr/enableFbc
      # above (both set to false there); the earlier `=1` overrides
      # were leftover from a pre-latency-tuning phase.
      # Why: i915.enable_psr=0 — panel self-refresh on Ivy Bridge uses
      # a software frontbuffer-tracking workqueue; re-enable on screen
      # update costs 1-5 ms of added latency per kernel.org i915 docs
      # (drivers/gpu/drm/i915/display/intel_psr.c). Negligible battery
      # win vs perceptible lag under 2C/4T saturation.
      # Why: i915.enable_fbc=0 — framebuffer compression on Gen 7 taints
      # the kernel ("Setting dangerous option enable_fbc") and introduces
      # intermittent panel glitches on MBP 9,2 per prior project notes.
      # i915.fastboot was removed in kernel 6.19+ (not 6.x-or-earlier), so
      # specifying it now is a no-op. Do not re-add.
      "i915.enable_fbc=0"
      "i915.enable_psr=0"
    ];

    # MacBook-specific kernel modules
    kernelModules = [
      "i915" # Intel HD4000 GPU
      "snd_hda_intel" # Audio codec
      "btusb" # Bluetooth USB
      "sdhci" # SD card reader
      "sdhci-pci" # SD card reader PCI bridge
    ];
  };

  # cpufreq_schedutil is built-in since kernel 5.7 (CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y).
  # NixOS auto-adds it to kernelModules via powerManagement.cpuFreqGovernor,
  # producing a harmless but loud systemd-modules-load failure every boot.
  # modprobe 'install' stub = run /bin/true instead of loading. Silent success.
  boot.extraModprobeConfig = ''
    install cpufreq_schedutil /run/current-system/sw/bin/true
  '';

  # Mask the 4 virtual serial ports — nothing connected, they each add 23 s
  # to boot waiting for devtty timeouts. All in parallel so real wallclock
  # impact is smaller but cleaner to eliminate.
  systemd.suppressedSystemUnits = [
    "dev-ttyS0.device"
    "dev-ttyS1.device"
    "dev-ttyS2.device"
    "dev-ttyS3.device"
    "sys-devices-platform-serial8250-serial8250:0-serial8250:0.0-tty-ttyS0.device"
    "sys-devices-platform-serial8250-serial8250:0-serial8250:0.1-tty-ttyS1.device"
    "sys-devices-platform-serial8250-serial8250:0-serial8250:0.2-tty-ttyS2.device"
    "sys-devices-platform-serial8250-serial8250:0-serial8250:0.3-tty-ttyS3.device"
  ];

  # ============================================================================
  # Nix Daemon — Ivy Bridge i5 is 2C/4T
  # ============================================================================
  # max-jobs and cores: NOT overridden here. Layered defaults handle it:
  #   nix.nix module sets max-jobs = mkDefault "auto" (local builds enabled)
  #   remote-builder client ON → build hook tries remote FIRST (nix architecture
  #     guarantee), falls back to local when SSH fails. No max-jobs override needed.
  #   cores: nix.nix module default 0 (use all threads). On 2C/4T that's 4.
  # nrb checks builder reachability and injects --builders "" when unreachable
  # to skip SSH timeout delays (~2min per derivation without this).
  #
  # Idle scheduling is the real throttle — daemon yields to GUI completely.
  # WiFi + 2C/4T: stalled downloads block the single build slot longer.
  nix.settings.stalled-download-timeout = 60;
  nix.settings.extra-sandbox-paths = [ "/dev/kvm" ];
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # Memory/zram tuning (supplements CachyOS defaults)
  # Memory / zram tuning — derived from Pop!_OS and Arch zram-wiki 2025 guidance
  # for 16 GB laptops using zstd zram. vm.page-cluster=0 is required with zstd
  # (random-access pool); vm.min_free_kbytes=100000 eliminates the 0.5-1 s
  # UI freeze before swap engages on sudden memory bursts.
  boot.kernel.sysctl = {
    # swappiness 100 (was 180). 180 is the kernel max and told the allocator
    # to compress anything into zram before evicting file cache. Under CPU
    # pressure (nix eval + codium + chrome) zstd compression becomes the
    # bottleneck — burning 2-core Ivy Bridge CPU on compression while real
    # work starves. 100 balances anon→zram vs. file-cache drop.
    "vm.swappiness" = lib.mkForce 100;
    "vm.page-cluster" = lib.mkForce 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.min_free_kbytes" = 100000;
    # vfs_cache_pressure 100 (was 500, kernel default). 500 aggressively
    # dropped dentries — fatal for nix workloads that re-walk /nix/store
    # (millions of inodes) repeatedly. 100 keeps dentries cached across
    # nix operations → fewer re-reads → less SATA queue churn.
    "vm.vfs_cache_pressure" = lib.mkForce 100;
  };

  # Qt6/Plasma on HD 4000: Vulkan support on Gen7 is non-conformant 1.0 only.
  # Force the OpenGL RHI backend so Qt6 doesn't sporadically probe Vulkan.
  environment.sessionVariables = {
    QSG_RHI_BACKEND = "opengl";
    # VAAPI on HD 4000 uses the legacy i965 driver (intel-media-driver is
    # Broadwell+). Offloads H.264 decode to iGPU → big CPU savings on
    # video playback + lower thermals. Flatpak browsers need `--filesystem=
    # /dev/dri` permission to pick this up (flatpak override).
    LIBVA_DRIVER_NAME = "i965";
  };

  # Apple firmware is picky about NVRAM — install to fallback EFI path instead.
  boot.loader.refind.efiInstallAsRemovable = true;
  # Disable canTouchEfiVariables since we're using removable install.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # vm.compaction_proactiveness = 0 now set by myModules.tuning.sysctls
  # (imported via flake-module.nix). Rationale stays the same: compaction
  # background thread can consume 5-10% of a core on memory-fragmented
  # systems; kernel reclaim under actual pressure handles defrag just fine.

  # Add the i965 legacy VAAPI driver for HD 4000. mesa already handles
  # GL/Vulkan; libvdpau-va-gl is just the VDPAU bridge.
  hardware.graphics.extraPackages = [ pkgs.intel-vaapi-driver ];

  # libva-utils ships `vainfo` — use it to confirm HW H.264/VC-1/VP9 decode
  # actually attaches on this HD 4000 after every upgrade. Tiny package.
  environment.systemPackages = [ pkgs.libva-utils ];

  # Boot cleanup: nothing on this host needs the network up before login.
  # NetworkManager-wait-online adds ~5 s to boot for no benefit here.
  systemd.services.NetworkManager-wait-online.enable = false;

  # drkonqi-coredump-pickup (KDE) times out after 30 min and marks the user unit
  # failed on every session. Known upstream Qt/Plasma issue — disable it.
  systemd.user.services.drkonqi-coredump-pickup.enable = false;

  # zram size cap: 50 % of RAM (was cachyos-settings default 100 %).
  # At 100 % the kernel targets 16 GB of compressed pages on a 16 GB
  # laptop — the RAM required to HOLD the compressed pool (~500 MB per
  # 1.3 GB original data at 3× zstd ratio) ends up competing with the
  # apps it's trying to help. 50 % leaves genuine RAM headroom for file
  # cache and running processes while still giving 8 GB of swap capacity.
  zramSwap.memoryPercent = lib.mkForce 50;

  # zram idle-recompression timers intentionally NOT enabled on MBP.
  # The re-compression pass burns 2-core Ivy Bridge CPU on zstd:9 during
  # memory pressure — exactly when the CPU is already saturated. These
  # timers were present in earlier revisions and removed here because
  # they made hangs worse, not better. (Ryzen host can keep them if
  # desired — high-core-count CPU has headroom.)

  # ============================================================================
  # TLP — Ivy Bridge works better with powersave even on AC (P-State still boosts)
  # ============================================================================
  services.tlp.settings = {
    # With intel_pstate=passive, governor "powersave" pins min freq → feels broken.
    # schedutil is the correct dynamic governor for non-HWP Ivy Bridge.
    CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "schedutil";
    CPU_SCALING_GOVERNOR_ON_BAT = lib.mkForce "schedutil";
    CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkForce "balance_performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = lib.mkForce "power";
    PLATFORM_PROFILE_ON_AC = lib.mkForce "balanced";
    SATA_LINKPWR_ON_AC = lib.mkForce "max_performance"; # Full SATA speed on AC
    SATA_LINKPWR_ON_BAT = lib.mkForce "med_power_with_dipm"; # Power save on battery
    # BCM4331 drops WiFi under any power saving — disable on AC *and* BAT.
    WIFI_PWR_ON_AC = lib.mkForce "off";
    WIFI_PWR_ON_BAT = lib.mkForce "off";
  };

  # ============================================================================
  # Services
  # ============================================================================
  services = {
    gvfs.enable = true; # GVFS for Nautilus/Dolphin network browsing

    # Disable services that waste resources on this MacBook
    thermald.enable = lib.mkForce false; # mbpfan + TLP handle thermal/power — thermald conflicts
  };

  # No cellular modem, no need for ModemManager
  systemd.services.ModemManager.enable = lib.mkForce false;

  # I/O scheduler: mq-deadline for SATA SSDs on MBP 9,2.
  # `none` is usually best for NVMe/multi-queue hardware, but this MBP uses
  # `libata.force=noncq` (hardware workaround for Intel 7-series chipset NCQ
  # bug), which limits the controller to ONE outstanding I/O at a time.
  # Under that constraint, mq-deadline is critical: it prioritizes reads
  # over writes and enforces a write-age timeout, preventing swap-in from
  # starving behind btrfs commit writes — exactly the cascade that caused
  # the 120 s hung-task → journald watchdog timeout hangs (see dmesg
  # analysis).
  # Second remote builder. Identity from site registry.
  # Uses same remotebuild SSH key as ryzen (reused across builders).
  # List-merge: nix.buildMachines from remote-builder module + this entry.
  nix.buildMachines =
    let
      wb = site.network.builders.aux;
    in
    [
      {
        inherit (wb) hostName;
        protocol = "ssh-ng";
        systems = [ "x86_64-linux" ];
        maxJobs = 20;
        speedFactor = 15;
        sshUser = "remotebuild";
        sshKey = "/root/.ssh/remotebuild";
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
    ];
  programs.ssh.knownHosts."aux-builder" =
    let
      wb = site.network.builders.aux;
    in
    {
      hostNames = [ wb.hostName ];
      inherit (wb) publicKey;
    };

  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x1e31", ATTR{power/wakeup}="disabled"
  '';
  # XHC1 udev rule: Ivy Bridge Panther Point xHCI (8086:1e31) has broken PCI
  # INT A routing on MBP 9,2 ("PCI INT A: no GSI" at boot) and a firmware
  # bug where port-status-change bits aren't cleared after S3, causing the
  # controller to stop firing interrupts on resume. Keyboard/trackpad are on
  # EHCI (USB 2.0), not XHC1 (USB 3.0) — disabling XHC1 wakeup only affects
  # external USB 3.0 ports. Source: linux-usb mailing list (Ivy Bridge xHCI),
  # Arch Wiki Power_management/Wakeup_triggers.

  # Plymouth: use breeze theme instead of bgrt (bgrt causes interlace glitch on i915)
  boot.plymouth.theme = lib.mkForce "breeze";

  # ============================================================================
  # Filesystems
  # ============================================================================
  # Override the @tmp BTRFS subvolume from hardware-configuration.nix — RAM-backed
  # tmpfs is faster and avoids wearing the SSD with temporary file writes.
  fileSystems."/tmp" = {
    device = lib.mkForce "tmpfs";
    fsType = lib.mkForce "tmpfs";
    options = lib.mkForce [
      "mode=1777"
      "noatime"
      "noexec"
      "nosuid"
      "nodev"
      "size=8G" # Half of 16GB RAM
    ];
  };

  # ============================================================================
  # journald watchdog extension
  # ============================================================================
  # Default WatchdogSec = 3 min. On MBP under SATA I/O saturation journald
  # sometimes can't complete a write cycle in 3 min — systemd then kills
  # journald and the whole logging pipeline, which ironically hides the
  # root-cause evidence. 10 min gives headroom to finish a transaction
  # under peak write pressure without masking a real hang (journald still
  # gets killed if truly dead).
  systemd.services.systemd-journald.serviceConfig.WatchdogSec = lib.mkForce "10min";

  # ============================================================================
  # journald retention
  # ============================================================================
  # Default SystemMaxUse (nixpkgs) = 50M. On this host, one busy boot fills 50M
  # in about 3.5 h, so every prior boot's logs are gone by the time we want to
  # investigate a crash. Evidence from 2026-04-16: two KDE session kicks at
  # 10:05 and 10:19 today were unattributable in part because the 07:28 — 10:25
  # window had already rolled over the user-1000 journal archives.
  # 500M gives ~30 h coverage and survives across one reboot, while still
  # being < 1 % of the 55 GB btrfs root.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    SystemKeepFree=1G
  '';

  # ============================================================================
  # Specialisation — CachyOS LTO (v2-compatible) kernel
  # ============================================================================
  # Second systemd-boot entry that boots the MacBook on CachyOS mainline
  # + LTO + BORE — compiled for x86-64-v2 so Ivy Bridge HD4000 boots it.
  # Overrides: kernel variant, microarch, BORE scheduler, and
  # system.nixos.label. applesmc+at24 patches stay OFF on both base
  # (xanmod) and this cachyos-lto-7.0 specialisation — patch file targets
  # mainline 6.19 layout (6 of 7 hunks fail on 7.0); deferred until
  # someone re-ports the hunks. xanmod has equivalent fixes inlined;
  # cachyos boot gets vanilla applesmc with possibly-different keyboard
  # backlight behaviour.
  #
  # OFFLINE WORKFLOW — important:
  # When ryzen is NOT reachable (travelling, different network, etc.),
  # flip `myModules.nix.remoteBuilder.client.enable = false` BEFORE
  # running nrb on mac. That gates out this entire specialisation block
  # so nix won't try to build the LTO kernel locally (2-3 hours on
  # 2C/4T i5-3210M). The default xanmod entry keeps working unchanged.
  # When back on network with ryzen, flip it back to true → ryzen
  # builds any missing cachyos bits on demand → mac pulls via ssh-ng.
  #
  # Build distribution is gated on remote-builder: the specialisation is
  # ONLY declared when myModules.nix.remoteBuilder.client.enable = true.
  # So the flow is:
  #
  #   remote-builder ON  →  spec declared → ryzen builds the LTO kernel,
  #                         macbook pulls over SSH, boot menu has both.
  #   remote-builder OFF →  spec silently vanishes, nrb only builds xanmod,
  #                         no 3-hour local LTO compile on 2C/4T.
  #
  # The guard is pure nix-eval (config.myModules.nix.remoteBuilder...) —
  # no runtime probing. Going offline: set the flag false BEFORE nrb. Back
  # online: flip true, nrb, ryzen builds on demand, cached in its store
  # for future mac rebuilds.
  #
  # How to pick at boot (when declared):
  #   1. reboot
  #   2. at Mac boot picker (hold ⌥ at chime) → pick EFI boot
  #   3. at systemd-boot menu → arrow-key to `macbook-pro-9-2-cachyos`
  #   Revert: arrow-key back to the default entry in systemd-boot.
  specialisation = lib.mkIf config.myModules.nix.remoteBuilder.client.enable {
    cachyos.configuration = {
      myModules.boot.kernel = {
        # Why: tests CachyOS perf on Ivy Bridge without disturbing proven-
        # stable xanmod main. User picks per-boot from systemd-boot menu.
        variant = lib.mkForce "cachyos-lto";
        # mArch inherited from base — myModules.host.tier = "v2" auto-derives "x86-64-v2".
        # Why: xanmod ships EEVDF only; BORE takes effect only on cachy.
        cachyos.cpusched = lib.mkForce "bore";
      };
      # Patches DISABLED on cachyos spec: the patch file was authored
      # against mainline 6.19 source, and 6 of 7 hunks reject on 7.0
      # (drivers/hwmon/applesmc.c got refactored again 6.19 → 7.0).
      # Deferred until somebody ports the patch to the 7.0 layout
      # (review current drivers/hwmon/applesmc.c + rewrite the hunks).
      # Until then the cachyos boot gets vanilla applesmc — keyboard
      # backlight may behave differently on the cachyos entry; xanmod
      # main still has its own upstream applesmc fixes.
      # applesmc patches removed — upstream kernel 7.0+ has all fixes.
      # Why: APPEND to the auto-generated label (nixpkgs default is
      # "<release>.<date>.<commit>", e.g. "26.05.20260414.4bd9165")
      # instead of replacing it. Boot menu then shows
      #   `NixOS 26.05.20260414.4bd9165` for main (default boot)
      #   `NixOS 26.05.20260414.4bd9165-cachyos-lto-v2` for spec
      # Both entries keep the full generation identity; the suffix
      # just distinguishes which kernel stack booted.
      # mkForce applies to the whole string so we rebuild the label
      # from config.system.nixos (version/rev/date).
      system.nixos.label = lib.mkForce "${config.system.nixos.release}${
        config.system.nixos.versionSuffix or ""
      }-cachyos-lto-v2";
    };
  };
}
