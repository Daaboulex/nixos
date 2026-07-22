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
    ./backup.nix
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
        # Hybrid: systemd-boot owns the NixOS generation menu (NVRAM
        # entry, refreshed every nrb). rEFInd installs at the Apple
        # firmware fallback path (/EFI/BOOT/BOOTX64.EFI — picked via ⌥
        # at chime) and chainloads systemd-boot when "NixOS" is selected.
        # Both installers run independently on every rebuild; both
        # menus stay fresh — drift is impossible.
        systemdBoot = {
          enable = true;
          # 511 MB ESP + dual-bootloader install + cachyos-lto kernels (~80 MB
          # per gen, kernel + initrd). 3 gens leaves ample headroom; 10 fills it.
          configurationLimit = 3;
        };
        refind = {
          enable = true;
          efiInstallAsRemovable = true;
          timeout = 10;
          maxGenerations = 3;
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
          # Chainload entry — picks systemd-boot's gen menu directly.
          # Add macOS/Windows here later via the same pattern (refind-nix
          # extraEntries submodule).
          extraEntries = [
            {
              name = "NixOS (systemd-boot)";
              loader = "/EFI/systemd/systemd-bootx64.efi";
            }
          ];
        };
        secureBoot.enable = false; # MacBook Pro 9,2 firmware doesn't support custom keys
        plymouth.enable = true;
      };
      impermanence.enable = false;
      # Off until user-password.age exists in the site registry (the
      # module's assertions then hold the rest of the /etc contract);
      # flip together with users.passwordFromSite, activate via
      # nrb --boot + reboot, never a live switch.
      etcOverlay.enable = false;
      hibernate = {
        # Kingston A400 holds a 16 GB LUKS-encrypted swap partition. Initrd
        # unlocks it via the same passphrase chain as cryptroot (cryptsetup
        # caches the passphrase) and wires it as resume device so the MBP
        # hibernates cleanly. zram (priority 100) handles steady-state
        # pressure; disk swap (priority 10) mainly carries the hibernate image.
        enable = true;
        swapLuksUuid = "4728138f-08c2-4fa2-a77b-3e12e3c1347c";
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
        # Ryzen's ed25519 host public key (cat /var/lib/ssh/ssh_host_ed25519_key.pub).
        # Rotates rarely; update here + nrb if ryzen reinstalls.
        inherit (site.hosts.macbook-pro-9-2.ssh.remoteBuilder) hostPublicKey;
        extraHostNames = [
          "ryzen-9950x3d"
        ];
        # null → no /etc/hosts pin. ryzen-9950x3d.local resolves purely via
        # mDNS, so it tracks ryzen's current DHCP lease instead of going stale
        # when the IP drifts — which is exactly what broke ssh + remote builds
        # (pinned .113, ryzen had drifted to .110).
        staticIp = null;
      };
      server.enable = false; # laptop doesn't serve builds
    };

    # --------------------------------------------------------------------------
    # Users
    # --------------------------------------------------------------------------
    users = {
      enable = true;
      # Off until user-password.age exists in the site registry; flipped
      # together with boot.etcOverlay by the overlay migration.
      passwordFromSite = false;
    };

    # --------------------------------------------------------------------------
    # Storage
    # --------------------------------------------------------------------------
    storage = {
      filesystems = {
        enable = true;
        enableLinux = true;
        enableWindows = true; # NTFS for /mnt/Windows SSD
        enableMac = true;
        enableOptical = true;
      };
      fstrim.enable = true;
      # btrbk is configured by backup.nix (enable = mkForce true +
      # targetPath = /mnt/kingston-backup); this exhaustive-reference
      # false is overridden there.
      btrbk.enable = false;
    };

    # --------------------------------------------------------------------------
    # Services
    # --------------------------------------------------------------------------
    services = {
      # mDNS resolution is via systemd-resolved (hardware.networking.multicastDns
      # = "resolve") — per-link, so it survives the Mullvad tunnel being the default
      # route, which broke avahi's nss-mdns own-multicast. Disabled here to free UDP
      # 5353 for resolved.
      avahi.enable = false;
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
        # mullvad-daemon falls back to wg-userspace if the kernel WireGuard
        # module isn't pre-loaded, then auto-locks all traffic (the
        # `Failed to set IPv6 address (ENOENT)` failure). Daaboulex/mullvad-vpn-
        # nix@41ba6ce loads the wireguard kmod + orders the daemon after
        # systemd-modules-load to prevent it.
        # `tunnel.ipv6 = false` kept as defense-in-depth: ISP has no IPv6
        # routing anyway, and a future kernel/hardening change that drops
        # the WG kmod would re-trigger the original bug if v6-in-tunnel
        # were enabled. Belt + suspenders.
        enable = true;
        # Personal policy — must stay identical to ryzen-9950x3d/default.nix.
        # Mullvad's `lockdown_mode` IS the kill switch (one field, same thing).
        settings = {
          # ── daemon-level toggles ──
          # Manual-connect policy: the tunnel comes up only on request.
          # Accepted trade-off: until connected, DNS + apps use the real
          # IP. `lan = true` keeps local subnet devices (printer, phone
          # USB tethering — NOT WiFi tether) reachable.
          autoConnect = false;
          lockdownMode = false; # kill switch OFF (intentional) — clearnet survives a tunnel drop
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
      splitTunnel.enable = true; # On-demand split-tunnel VPN -- internal files + mail only
      sunshine.enable = false; # No game streaming from the MacBook
      syncthing = {
        enable = false; # disabled: stale DBs + unfinished cross-CLI symlink arch; ssh+rsync instead
        # Kingston A400 (DRAM-less SATA) + btrfs = metadata storm when the
        # full-folder scan runs at boot. Delay by 120 s so KDE settles first.
        startDelay = 120;
        relaysEnabled = true;
        globalAnnounceEnabled = true;
        devices.ryzen-9950x3d.id = site.hosts.ryzen-9950x3d.syncthing.deviceId;
        devices.pixel-9-pro = {
          id = site.hosts.pixel-9-pro.syncthing.deviceId;
          addresses = [ "dynamic" ];
        };
        folders = {
          documents = {
            path = "/home/user/Documents";
            devices = [
              "ryzen-9950x3d"
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
      };
      ssh = {
        enable = true;
        inherit (site.hosts.macbook-pro-9-2.ssh) trustedKeys;
        extraIgnoreSubnets = [ site.network.subnet ]; # loopback baseline is the ssh module default
      };
      agenix = {
        enable = true;
        # split-tunnel VPN client PKI (consumed by myModules.services.splitTunnel).
        # The login password is NOT here -- it is agent-owned in KWallet.
        secrets.split-tunnel-ca = { };
        secrets.split-tunnel-cert = { };
        secrets.split-tunnel-key = { };
        secrets.split-tunnel-pass = { }; # VPN login password (env SPLIT_TUNNEL_PASS)
        # .age ciphertext is tracked in git (safe — only host private keys
        # decrypt it; agenix reads it from the flake source). Recipients (fleet
        # host keys) live in secrets/secrets.nix; edit/rekey via
        # `agenix -e secrets/<name>.age`.
        secrets.wifi = { }; # WIFI_PSK=… — consumed by hardware.networking.homeWifi
        # secrets.user-password = { }; # uncomment with users.passwordFromSite (the ceremony creates the blob first)
      };
      portmaster = {
        enable = false;
        notifier = true; # (default) — system tray icon
        autostart = true; # Start on boot
        # Mullvad + Portmaster stack. See ryzen-9950x3d/default.nix for
        # the full rationale: `dnsQueryInterception=false` is required
        # to avoid the Mullvad-bootstrap deadlock at boot.
        # See ryzen-9950x3d/default.nix for the rationale on why each of
        # these keys MUST live in forceSettings. UI changes to them will
        # be reverted on next boot.
        forceSettings = {
          # Unlocks the Experimental-level interception toggle below --
          # Portmaster silently ignores a set value for an option above
          # the global release level (see ryzen for the full mechanics).
          "core/releaseLevel" = "experimental";
          "filter/dnsQueryInterception" = false;
          "dns/nameservers" = [
            "dot://dns.mullvad.net?ip=194.242.2.3&name=MullvadAdblockDoT&blockedif=empty"
            "dot://dns.quad9.net?ip=9.9.9.9&name=Quad9&blockedif=empty"
            "dot://dns.quad9.net?ip=149.112.112.112&name=Quad9&blockedif=empty"
            "dot://dns.mullvad.net?ip=194.242.2.2&name=MullvadUnfilteredDoT&blockedif=empty"
          ];
          "dns/noAssignedNameservers" = true;
          # Reject plaintext DNS in Portmaster's internal resolver.
          "dns/noInsecureProtocols" = true;
          # SPN and Mullvad both reroute all traffic (mutually exclusive); lock
          # SPN off so a UI toggle cannot enable it. See ryzen for full rationale.
          "spn/enable" = false;
        };
      };
      # See parts/security/portmaster-mullvad-compat.nix for the full
      # rationale. Required on every host where Portmaster and Mullvad
      # both run, otherwise the tunnel can't bootstrap after a reconnect.
      portmasterMullvadCompat.enable = false;
      # Keep Portmaster's per-connection resolver-compliance verdicts off
      # the split-tunnel DNS chain: office .local queries to the loopback
      # rewriter otherwise flap into ICMP blocks. See
      # parts/security/portmaster-split-tunnel-compat.nix.
      portmasterSplitTunnelCompat.enable = false;
    };

    # --------------------------------------------------------------------------
    # Hardware
    # --------------------------------------------------------------------------
    hardware = {
      core.enable = true;
      smartd.enable = true;
      networking = {
        enable = true;
        # openPorts = []; # (default)
        # openPortRanges = []; # (default)
        # mDNS via systemd-resolved (per-link) instead of avahi's nss-mdns, whose
        # own multicast follows the default route and dies out the Mullvad tunnel
        # when the VPN is up. "resolve" = resolve .local only (this host needn't
        # advertise) → no wg0 handling needed. Frees :5353 via avahi disabled below.
        multicastDns = "resolve";
        homeWifi.enable = true; # declarative home WiFi profile (SSID from site, PSK from agenix)
        vpnPlugins = [ pkgs.networkmanager-openvpn ]; # KDE OpenVPN import (25.11 dropped the default plugins)
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
        # false here -> the gpu-intel module emits i915.enable_X=0 (explicit disable):
        kernelParams = {
          enablePsr = false; # PSR flickers on MBP 2012 + its SW frontbuffer-tracking adds 1-5ms latency
          enableFbc = false; # FBC taints the kernel ("dangerous option") + glitches on MBP 9,2
          enableDc = false; # Display C-states unstable on Ivy Bridge
        };
        openCL = false; # HD4000 is Gen7 (crocus); iris is Gen8+ and rusticl does not support crocus -- no GPU OpenCL exists here, so the iris rusticl contribution is dead weight
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
        kvm.enable = true; # (default) — virtualization (VT-x)
        updateMicrocode = true; # (default)
        iommu.enable = false; # No VT-d passthrough needed
      };
      # AMD CPU: not imported on this host (see flake-module.nix)
      # performance is configured by tuning.performance below
      power = {
        enable = true;
        tlp = true; # battery charge limits + AC/BAT scaling (this host is the laptop)
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
      # sched-ext (scx_lavd) on this i5-3210M is enabled but marginal, with two
      # caveats. scx#3474 — `scx_cgroup_move_task` WARN in kernel/sched/ext.c on
      # 6.19.x; the ops.cgroup_move() rq-tracking fix may not be in cachyos-lto
      # 7.0.0 (check dmesg).
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
      # Revert (enable = false) if dmesg shows a cgroup_move WARN, input
      # regresses, or the KDE session destabilizes.
      scx = {
        enable = true;
        scheduler = "scx_lavd";
      };
    };

    # --------------------------------------------------------------------------
    # Diagnostics
    # --------------------------------------------------------------------------
    diagnostics.nftables.enable = true; # nft CLI -- read the live split-tunnel alias table + firewall (sudo)
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
      # cachyos-lto for x86-64-v2 (Ivy Bridge HD4000) — the eval canary in
      # parts/_build/tests.nix pins this choice. v2 has no upstream binary
      # cache, so kernel rotations compile from source -- build on the
      # remote-builder (ryzen) when reachable, else a slow local 2C/4T build.
      variant = "cachyos-lto";
      #channel = "latest";
      # mArch defaults to "x86-64-v2" via myModules.host.tier = "v2". No explicit override needed.
      extraParams = [
        "vt.global_cursor_default=0" # Hide kernel text cursor
        "nmi_watchdog=0" # Disable NMI hard lockup detector (frees PMU counter); keeps soft lockup + iTCO_wdt active for hang diagnosis
        "mem_sleep_default=deep" # S3 deep sleep (better battery on suspend)
        "acpi_enforce_resources=lax" # Allow ACPI resource access for sensors
      ];
      cachyos = {
        cpusched = "bore"; # BORE scheduler — desktop-interactive tuning
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
      # 3.0Gbps IS applied and is the real fix. The `noncq` token is NOT honored by
      # this controller -- the drive still reports NCQ depth 32, and the link has
      # been error-free at 3.0Gbps with NCQ on -- so it is kept only as belt-and-
      # suspenders in case a future kernel/controller honors it. Drop to 1.5Gbps
      # only if ata interface-fatal errors ever reappear.
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
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # Memory/zram tuning (supplements CachyOS defaults)
  # Memory / zram tuning — derived from Pop!_OS and Arch zram-wiki 2025 guidance
  # for 16 GB laptops using zstd zram. vm.page-cluster=0 is required with zstd
  # (random-access pool); vm.min_free_kbytes=100000 eliminates the 0.5-1 s
  # UI freeze before swap engages on sudden memory bursts.
  boot.kernel.sysctl = {
    # swappiness 150: with zram on lz4 (cheap to compress), eagerly compressing anon
    # pages into zram beats evicting file cache -- lz4 removed the zstd CPU cost that
    # previously forced this down to 100. Matches the cachyos default for this host.
    "vm.swappiness" = lib.mkForce 150;
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

  # canTouchEfiVariables off (Apple firmware is picky about NVRAM); the removable
  # EFI install itself is owned by myModules.boot.loader.refind.efiInstallAsRemovable.
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

  # zram algorithm: lz4, not the cachyos zstd default. On this 2-core CPU the zstd
  # compression itself becomes the bottleneck under memory+CPU pressure (exactly
  # when both cores are already saturated); lz4 is ~3-4x cheaper to (de)compress at
  # a lower ratio -- the right trade on 16 GB, where the lost swap-capacity headroom
  # is not needed. (ryzen keeps zstd -- it has cores to spare.)
  zramSwap.algorithm = lib.mkForce "lz4";

  # zram idle-recompression timers intentionally NOT enabled on MBP.
  # The re-compression pass burns 2-core Ivy Bridge CPU on zstd:9 during
  # memory pressure — exactly when the CPU is already saturated. These
  # timers were present in earlier revisions and removed here because
  # they made hangs worse, not better. (Ryzen host can keep them if
  # desired — high-core-count CPU has headroom.)

  # ============================================================================
  # TLP -- Ivy Bridge (i5-3210M): intel_pstate passive, no HWP, scx_lavd
  # ============================================================================
  # Governor stays schedutil on AC and BAT: scx_lavd drives CPU frequency through
  # schedutil's hint path, so the performance governor would override scx's
  # per-task decisions rather than help. Turbo (CPU_BOOST) is the ONLY effective
  # CPU perf lever here -- in passive mode with no HWP/EPP and no EPB sysfs,
  # CPU_ENERGY_PERF_POLICY / CPU_*_PERF_PCT / PLATFORM_PROFILE are silent no-ops.
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "schedutil";
    CPU_SCALING_GOVERNOR_ON_BAT = lib.mkForce "schedutil";
    CPU_BOOST_ON_AC = 1; # allow turbo on AC = max performance
    CPU_BOOST_ON_BAT = 0; # no turbo on BAT = thermal + battery savings
    SATA_LINKPWR_ON_AC = lib.mkForce "max_performance"; # full SATA speed on AC
    SATA_LINKPWR_ON_BAT = lib.mkForce "med_power_with_dipm"; # link power save on battery
    USB_EXCLUDE_BTUSB = 1; # exempt Bluetooth from USB autosuspend (Broadcom combo stability)
    # BCM4331 drops WiFi under any power saving -- disable on AC and BAT.
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
  # `none` is usually best for NVMe/multi-queue hardware, but on this single-
  # queue SATA link (3.0Gbps; the noncq token is NOT honored, NCQ stays on --
  # see the kernel-params comment) mq-deadline still matters: it prioritizes
  # reads over writes and enforces a write-age timeout, preventing swap-in
  # from starving behind btrfs commit writes -- exactly the cascade that
  # caused the 120 s hung-task -> journald watchdog timeout hangs.
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
  # Registry name/key pins — hosts the resolver cannot name (mDNS is
  # link-local, never crosses a routed VPN; the DoT resolver bypasses foreign
  # DNS) plus the aux builder. Every identifying value lives in the private
  # registry.
  networking.hosts = lib.listToAttrs (
    map (e: lib.nameValuePair e.ip e.names) site.network.pins.etcHosts
  );
  programs.ssh.knownHosts =
    site.network.pins.sshKnownHosts
    // (
      let
        wb = site.network.builders.aux;
      in
      {
        aux-builder = {
          hostNames = [ wb.hostName ];
          inherit (wb) publicKey;
        };
      }
    );

  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x1e31", ATTR{power/wakeup}="disabled"
    ${lib.concatMapStringsSep "\n    " (
      pid:
      ''ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="${pid}", TAG+="systemd", ENV{SYSTEMD_WANTS}="pixel-adb-forward.service"''
    ) site.hosts.pixel-9-pro.adb.usbProductIds}
  '';

  systemd.services.pixel-adb-forward =
    let
      serial = site.hosts.pixel-9-pro.adb.serial;
    in
    {
      description = "ADB port forward for Pixel 9 Pro (SSH)";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = pkgs.writeShellScript "wait-for-adb" ''
          set -euo pipefail
          for i in $(seq 1 10); do
            state="$(${pkgs.android-tools}/bin/adb -s ${serial} get-state 2>/dev/null || true)"
            [ "$state" = device ] && exit 0
            sleep 1
          done
          echo "ADB device ${serial} not ready after 10s" >&2
          exit 1
        '';
        ExecStart = pkgs.writeShellScript "pixel-forwards" ''
          set -euo pipefail
          ${pkgs.android-tools}/bin/adb -s ${serial} forward tcp:22220 tcp:2222
        '';
        Restart = "on-failure";
        RestartSec = 5;
        User = config.myModules.primaryUser;
      };
    };
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
  # investigate a crash — by then the relevant window has already rolled over.
  # 2G gives roughly a week of boots to investigate against (500M sat at its
  # cap and only covered ~30 h), still < 1 % of the btrfs root; SystemKeepFree
  # yields to real disk pressure.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemKeepFree=1G
  '';

}
