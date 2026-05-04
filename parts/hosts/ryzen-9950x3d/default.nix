# ryzen-9950x3d — NixOS host config for Ryzen 9950X3D desktop (Zen 5, RX 9070 XT).
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
  ];

  # ============================================================================
  # MyModules Configuration — Exhaustive Reference
  # ============================================================================
  # Every myModules option is listed explicitly, even defaults, so this file
  # serves as a display config showing all available knobs. Options using their
  # module default are marked with # (default).
  # ============================================================================
  myModules = {

    # --------------------------------------------------------------------------
    # Host Identity
    # --------------------------------------------------------------------------
    host = {
      tier = "v4"; # Ryzen 9950X3D — Zen 5 with AVX-512
    };

    # --------------------------------------------------------------------------
    # Primary User
    # --------------------------------------------------------------------------
    # primaryUser = "user"; # (default)

    # --------------------------------------------------------------------------
    # Boot
    # --------------------------------------------------------------------------
    boot = {
      boot = {
        enable = true;
        loader = "systemd-boot"; # (default)
        secureBoot = {
          enable = true;
          # pkiBundle = "/var/lib/sbctl"; # (default)
        };
        plymouth = {
          enable = true;
          # theme uses module default
        };
        initrd.enable = true; # Systemd initrd (faster boot, needed for impermanence rollback)
        # consoleMode uses module default
      };

      # Impermanence — disabled until @persist + @root-blank subvolumes are created
      impermanence = {
        enable = false;
        # persistPath = "/persist"; # (default)
        # luksDevice = "cryptroot"; # (default)
        # rollback.enable = true; # (default)
        # rollback.blankSnapshot = "@root-blank"; # (default)
      };

      kernel = {
        enable = true;
        variant = "cachyos-lto";
        # channel = "latest"; # (default)
        # tier=v4 would auto-derive "x86-64-v4" (generic). Override to
        # "ZEN5" for Zen 5-specific compile target (narrower than v4 tier).
        mArch = "ZEN5";
        extraParams = [
          # loglevel=0 removed — Plymouth/Lanzaboote appends loglevel=4 which overrides it
          "vt.global_cursor_default=0"
          "amd_iommu=on"
          "iommu=pt"
          "nmi_watchdog=0" # Disable NMI hard lockup detector (frees PMU counter); keeps soft lockup + iTCO_wdt active
          "acpi_enforce_resources=lax"
          "pci=realloc"
          "usbcore.autosuspend=-1" # Disable USB autosuspend (fixes xhci_hcd suspend timeout)
          "noautogroup" # Disable sched autogroup at boot (closes race with sched_ext cgroup ops)
          "usbhid.quirks=0x0fd9:0x006d:0x00000400" # Stream Deck V2: NOGET quirk (fixes HID probe -110 timeout on port 1-2)
          "split_lock_detect=off" # Prevents perf drops in games using split-lock instructions
          "nvme_core.default_ps_max_latency_us=0" # Disable NVMe power state transitions (prevents micro-stutters)
          "tsc=reliable" # Pin TSC as clocksource — Zen 5 has invariant TSC
          "amdgpu.freesync_video=1" # FreeSync video mode — still opt-in on kernel 6.19
          "cma=64M" # Reserve 64MB contiguous DMA for Qualcomm WCN785x QMI firmware (ath12k)
        ];
        cachyos = {
          cpusched = "bore"; # BORE compiled into kernel as fallback; scx_bpfland overlays it via BPF when loaded
          bbr3 = true;
          hzTicks = "1000";
          kcfi = true;
          performanceGovernor = false; # powersave governor via P-State active mode is correct for Zen 5
          tickrate = "full";
          preemptType = "full";
          ccHarder = true;
          hugepage = "always";
        };
      };
    };

    # --------------------------------------------------------------------------
    # Nix
    # --------------------------------------------------------------------------
    nix.nix.enable = true;
    nix.nixLd.enable = true;
    # Accept builds from macbook-pro-9-2 over SSH. The remotebuild system
    # user gets added + marked nix trusted-user; the public key below
    # comes from `sudo cat /root/.ssh/remotebuild.pub` on the macbook.
    # Private key never leaves macbook; ryzen only needs the public half.
    nix.remoteBuilder = {
      server = {
        enable = true;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM4usrlyb46Vu1Bx+AXLCqg4A9fq6zKFkB9YKhkc38SP remotebuild-mac-to-ryzen"
        ];
      };
      client.enable = false; # desktop doesn't offload — it's the builder
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
      fstrim = {
        enable = true;
        interval = "weekly"; # (default)
      };
      btrbk.enable = false; # Ryzen has no second drive target configured
    };

    # --------------------------------------------------------------------------
    # Services
    # --------------------------------------------------------------------------
    services = {
      avahi.enable = true; # mDNS / zeroconf — resolves .local hostnames on LAN
      cups.enable = true;
      earlyoom = {
        enable = true;
        memoryThreshold = 5; # (default)
        swapThreshold = 10; # (default)
      };
      geoclue.enable = true; # Night light location
      mullvad = {
        # WiFi-break recovery (2026-04-16): same story as macbook-pro-9-2.
        # First nrb hit `Failed to set IPv6 address (ENOENT)` from
        # wg-userspace fallback (kernel WireGuard module not pre-loaded).
        # Resolved by Daaboulex/mullvad-vpn-nix@41ba6ce which now loads
        # the wireguard kmod + orders the daemon after systemd-modules-load.
        # `tunnel.ipv6 = false` kept as defense-in-depth: ISP has no IPv6
        # routing anyway, and a future kernel/hardening change that drops
        # the WG kmod would re-trigger the original bug if v6-in-tunnel
        # were enabled. Belt + suspenders.
        enable = true;
        # Personal policy — keep identical to macbook-pro-9-2/default.nix.
        # Mullvad's `lockdown_mode` IS the kill switch (one field, same thing).
        settings = {
          # ── daemon-level toggles ──
          # Always-on policy: tunnel up at boot, kill switch engaged.
          # Why: IP privacy is only real when tunnel is up. Prior config
          # (autoConnect=false, lockdownMode=false) left a window between
          # boot and manual connect where DNS + apps used the real IP.
          # Kill switch + `lan = true` still lets local subnet devices
          # (printer, phone tethering over USB — NOT WiFi tether) work.
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
          # ── obfuscation ──
          obfuscation.mode = "auto";
          # ── multihop ──
          multihop.enable = true;
          # ── API access methods ──
          apiAccess = {
            direct = true;
            mullvadBridges = true;
            encryptedDnsProxy = true;
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
          # ── relay constraints ──
          relay = {
            ipVersion = "any";
            ownership = "any";
            entryOwnership = "any";
          };
        };
      };
      sunshine = {
        enable = true;
        outputName = "1"; # KMS enumeration — test value
        adapterName = "/dev/dri/renderD128"; # RX 9070 XT (verified via udevadm + lspci)
        encoder = "vaapi"; # AMD on Linux via Mesa VAAPI
        streamAudioToClientAndHost = true; # Audio plays on desktop AND streams to Switch
        # Capture the GoXLR System output so game audio reaches both desktop + stream
        audioSink = "alsa_output.pci-0000_09_00.3.analog-stereo.monitor";
      };
      syncthing = {
        enable = true;
        devices.macbook-pro-9-2.id = site.hosts.macbook-pro-9-2.syncthing.deviceId;
        folders = {
          documents = {
            path = "/home/user/Documents";
            devices = [ "macbook-pro-9-2" ];
          };
          claude = {
            path = "/home/user/.claude";
            devices = [ "macbook-pro-9-2" ];
            ignorePerms = true;
            versioningMaxAge = "1209600"; # 14 days
          };
          gemini = {
            path = "/home/user/.gemini";
            devices = [ "macbook-pro-9-2" ];
            ignorePerms = true;
            versioningMaxAge = "1209600"; # 14 days
          };
          codex = {
            path = "/home/user/.codex";
            devices = [ "macbook-pro-9-2" ];
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
        trustedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5DIyEj88eLxYvf4UrvdWJ4mbPPVUtBT9LqIp5mRS7h laptop"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmK9yl3ndTzn5Qt42njlROMMf2LzOCjwzQwob1mrP9p desktop"
        ];
        fail2banIgnoreIPs = [
          "127.0.0.1/8"
          "::1/128"
          "192.168.2.0/24"
        ];
      };
      agenix = {
        enable = true;
        # identityPaths uses host SSH key by default
      };
      portmaster = {
        enable = true;
        notifier = true; # System tray icon (autostart)
        autostart = true; # Start on boot
        # MULLVAD + PORTMASTER STACK
        #
        # Post-tunnel topology (when `filter/dnsQueryInterception=false`):
        #   app DNS query
        #     → systemd-resolved → /etc/resolv.conf
        #     → Mullvad tunnel DNS (100.64.0.23 via wg0-mullvad)
        #     → applies Mullvad's ad/tracker/malware filter tier
        #     → authoritative resolve
        #   app TCP/UDP
        #     → Portmaster nfqueue (per-app firewall, filterlists, rules)
        #     → wg0-mullvad → Mullvad relay
        #
        # Why `dnsQueryInterception=false` is load-bearing:
        # Portmaster's packet_handler.go:467 rewrites every outbound :53
        # packet to its internal resolver — this is GLOBAL, ignores per-
        # profile allow rules. With our configured resolver being the
        # in-tunnel 100.64.0.23, pre-tunnel queries have no route, time
        # out, and mullvad-daemon can never resolve api.mullvad.net to
        # bring the tunnel up. Deadlock. Flipping this off lets mullvad-
        # daemon's bootstrap DNS go direct (Mullvad's nftables kill-
        # switch exempts its own daemon for bootstrap traffic). Once the
        # tunnel is up, systemd-resolved is pointed at 100.64.0.23 by
        # Mullvad, so all DNS still flows through Mullvad's filter tier
        # — we just drop Portmaster's intercept layer.
        #
        # Ref: service/firewall/packet_handler.go:467-483  (interception)
        # Ref: service/resolver/resolve.go:395,446         (offline fail)
        # Ref: wiki.safing.io/en/Portmaster/App/Compatibility/Software/MullvadVPN
        # These keys ALL live in forceSettings because the wrong value on
        # any of them breaks the Mullvad+Portmaster stack (see detailed
        # rationale for each below). Anything the user changes in the UI
        # here is reverted on next boot — intentional.
        forceSettings = {
          # Do NOT redirect outbound :53 to Portmaster's resolver.
          # Required to break the Mullvad bootstrap deadlock.
          "filter/dnsQueryInterception" = false;
          # Mullvad's public DoT resolver at 194.242.2.3 =
          # `adblock.dns.mullvad.net` — matches the filter tier of the
          # in-tunnel 100.64.0.23 (ads + trackers + malware). Using DoT
          # instead of plain `dns://100.64.0.23?...` keeps
          # `dns/noInsecureProtocols` at Portmaster's secure default.
          # With lockdownMode=true + default-route-via-wg0-mullvad, the
          # TLS traffic to 194.242.2.3:853 rides the same WireGuard
          # tunnel anyway — the TLS layer is belt-and-suspenders, not a
          # new egress path. Other Mullvad DoT tiers:
          #   194.242.2.2  dns.mullvad.net          (no filtering)
          #   194.242.2.4  base.dns.mullvad.net     (alt base)
          #   194.242.2.5  extended.dns.mullvad.net (+ social)
          #   194.242.2.6  family.dns.mullvad.net   (+ adult)
          #   194.242.2.9  all.dns.mullvad.net      (all filters)
          # URL format: hostname in URL, IP as `ip=` param. Supplying both
          # hostname and `verify=` is rejected by Portmaster's parser
          # (resolvers.go:243-249) — it must be one or the other. This
          # form matches Portmaster's own Quick Settings presets
          # (`dot://dns.quad9.net?ip=9.9.9.9&name=Quad9&...`).
          "dns/nameservers" = [
            "dot://dns.mullvad.net?ip=194.242.2.3&name=MullvadAdblockDoT&blockedif=empty"
          ];
          # Ignore DHCP-assigned system DNS so Portmaster doesn't fall
          # back to the ISP resolver while the tunnel is still coming up.
          "dns/noAssignedNameservers" = true;
        };
      };
      # Preserve Mullvad's WireGuard fwmark (0x6d6f6c65) from Portmaster's
      # CONNMARK --restore-mark. Without this, fresh Mullvad connections
      # get their policy-routing mark zeroed, encapsulated packets loop
      # back into wg0-mullvad, and the tunnel can't reach its relay until
      # Portmaster is paused. See parts/security/portmaster-mullvad-compat.nix.
      portmasterMullvadCompat.enable = true;
    };

    # --------------------------------------------------------------------------
    # Hardware
    # --------------------------------------------------------------------------
    hardware = {
      core.enable = true;
      networking = {
        enable = true;
        #openPorts = [24727]; # (default)
        #openPortRanges = [{ from = 24727; to = 24727; }]; # (default)
        # nameservers use module default
      };
      pipewire = {
        enable = true;
        lowLatency = true;
      };
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      graphics = {
        enable = true;
        enable32Bit = true; # (default)
        # Intel GPU: not imported on this host (see flake-module.nix)
        # NVIDIA GPU: not imported on this host (see flake-module.nix)
        # openCL.rusticlDrivers assembled automatically from GPU modules
        mesaGit = {
          enable = true; # Bleeding-edge Mesa from git main (RDNA 4 optimizations)
          drivers = [ "amd" ]; # Only compile AMD drivers (radeonsi, RADV) + essentials
        };
      };
      gpuAmd = {
        enable = true;
        vulkanDeviceId = "1002:7550"; # RX 9070 XT — force dGPU for Vulkan on dual-AMD systems
        vulkanDeviceName = "AMD Radeon RX 9070 XT"; # Substring match for DXVK/VKD3D device filter
        lact.enable = true;
        initrd.enable = true; # Load amdgpu early (faster display init)
        enablePPFeatureMask = true; # Full power management feature flags
        rdna4Fixes = true; # RDNA 4 stability kernel params
        drmDebug = false; # Was destroying ALL boot logs (~800 msg/sec overflows kmsg ring buffer)
        disableHDCP = false; # HDCP enabled (was disabled for RDNA 4 handshake debugging)
        openCL = true; # (default) — RustiCL radeonsi driver
      };
      cpuAmd = {
        enable = true; # AMD CPU optimizations (pstate, prefcore, kvm, microcode)
        pstate = {
          enable = true; # (default)
          mode = "active"; # (default)
        };
        prefcore.enable = true; # (default)
        x3dVcache = {
          enable = true; # Dual-CCD 3D V-Cache optimizer (works at CPPC firmware level — scheduler-independent)
          mode = "cache"; # Prefer CCD0 (96MB 3D V-Cache) for gaming
        };
        kvm.enable = true; # (default) — KVM virtualization
        updateMicrocode = true; # (default)
      };
      # Intel CPU: not imported on this host (see flake-module.nix)
      # performance moved to tuning.performance below
      power = {
        enable = true;
        laptop = false; # Not a laptop — no TLP
      };
      # MacBook: not imported on this host (see flake-module.nix)
    };

    # --------------------------------------------------------------------------
    # Sensors
    # --------------------------------------------------------------------------
    sensors = {
      nct6775.enable = true; # Nuvoton NCT6799 Super I/O — motherboard Vcore, fan speeds, temperatures
      zenpower.enable = true; # zenpower5 — Zen 5 Granite Ridge temps + RAPL power (replaces k10temp)
      ryzenSmu.enable = true; # SMU access for runtime CO read/write, PBO limits, boost override
      msr.enable = true; # MSR access — needed by CoreCyclerLx (clock stretch, RAPL)
    };

    # --------------------------------------------------------------------------
    # Input
    # --------------------------------------------------------------------------
    input = {
      yeetmouse = {
        enable = true;
        devices.g502 = {
          enable = true; # Libinput flat profile HWDB entries (prevents double acceleration)
          # Acceleration parameters are set via hardware.yeetmouse below
        };
      };
      duckyOneXMini.enable = true;
      ratbagd.enable = true;
      streamcontroller.enable = true;
    };

    # --------------------------------------------------------------------------
    # Desktop
    # --------------------------------------------------------------------------
    desktop = {
      plasma = {
        enable = true;
        xkbLayout = "us"; # (default)
        xkbVariant = ""; # (default)
        ddcBrightness = true; # DDC/CI brightness control via i2c-dev (PowerDevil)
      };
      flatpak.enable = true;
      displays = {
        enable = true;
        phantomUuids = [ "a460df66-ee57-4a8f-ba9b-4a877908e962" ];
        monitors = {
          main = {
            connector = "DP-1";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239757;
            };
            position = {
              x = 0;
              y = 0;
            };
            priority = 1;
            vrr = "automatic";
            edidHash = "9f311191c8a8ef17808acd6e824be682";
            edidIdentifier = "DEL 41313 811028053 18 2021 0";
            uuid = "3527f744-8931-4a23-a80e-55a2c9ec0fbe";
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":0.5},{"width":0.5}]}'';
          };
          portrait = {
            connector = "DP-2";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239761;
            };
            position = {
              x = 1920;
              y = -127;
            };
            priority = 2;
            rotation = "right";
            vrr = "automatic";
            edidHash = "32829c0ae88c33a9e3a9f349597d76af";
            edidIdentifier = "DEL 41219 810371157 26 2017 0";
            uuid = "069d4759-61df-4d8b-809e-cbb11fb33857";
            tiling.layout = ''{"layoutDirection":"vertical","tiles":[{"height":0.333},{"height":0.334},{"height":0.333}]}'';
          };
          crt = {
            connector = "HDMI-A-1"; # GPU HDMI
            alternateConnectors = [ "HDMI-A-3" ]; # Motherboard HDMI (fallback)
            mode = {
              width = 1280;
              height = 1024;
              refreshRate = 75025;
            };
            position = {
              x = 0;
              y = 56;
            };
            priority = 3;
            enabled = false;
            vrr = "never";
            uuid = "6b146127-4137-452c-a823-3f9b7ef75b14"; # CRT EDID-derived UUID (stable across ports)
            alternateUuids = [ "c808e708-83c0-4558-b83c-62dc0cae958f" ]; # Old kscreen UUID (stale)
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":1.0}]}'';
            toggle = {
              enable = true;
              scriptName = "crt-toggle";
              repositions."DP-1" = {
                x = 1280;
                y = 0;
              };
              repositions."DP-2" = {
                x = 3200;
                y = -127;
              };
            };
          };
        };
      };
    };

    # --------------------------------------------------------------------------
    # Hardware Access (udev rules for development probes)
    # --------------------------------------------------------------------------
    hardware.udevAccess = {
      enable = true;
      saleae = true;
      debuggingProbes = true;
    };
    hardware.acpid.enable = true;
    hardware.upower.enable = true;
    hardware.usbmuxd.enable = true;
    hardware.coolercontrol.enable = true; # Fan/cooling device management (daemon + GUI)
    hardware.goxlr = {
      enable = true;
      isMini = true;
      utility.enable = true; # (default)
      installProfiles = true; # (default)
    };

    # --------------------------------------------------------------------------
    # Diagnostics
    # --------------------------------------------------------------------------
    tuning.corecycler.enable = true; # Device access for CoreCyclerLx (package in HM)

    # --------------------------------------------------------------------------
    # VFIO — Stealth GPU Passthrough
    # --------------------------------------------------------------------------
    vfio = {
      enable = true;
      bindMethod = "dynamic"; # Libvirt hooks bind/unbind on VM start/stop
      restrictScxToHost = true; # Restrict scx to CCD1 (hostCpuMask) during VM — keeps scheduler on host cores
      hostCpuMask = "0xff00ff00"; # CCD1: cores 8-15 + threads 24-31
      # KWin GPU selection: dual-GPU by default (both iGPU + dGPU outputs active).
      # iGPU listed FIRST = primary render device. dGPU outputs (DP-1, DP-2, HDMI-A-1)
      # light up normally for Linux display.
      #
      # VFIO trade-off: KDE Bug 515835 (ASSIGNED, unfixed) — if KWin holds dGPU
      # outputs and dGPU is unbound (VM start), wl_output race kills Wayland clients.
      # Mitigation: `specialisation.vfio` below overrides to iGPU-only. Reboot into
      # that specialisation (SDDM session menu or boot menu) BEFORE starting a VM.
      #
      # NOTE: KWIN_DRM_DEVICES uses ':' as separator — PCI paths contain ':' and break
      # the parser. Use /dev/dri/cardN, not /dev/dri/by-path/pci-…. amdgpu enumerates
      # deterministically here (iGPU=card0, dGPU=card1).
      sessionGpuDevices = [
        "/dev/dri/card0" # iGPU — primary render (Zen 5, HDMI-A-3)
        "/dev/dri/card1" # dGPU — RX 9070 XT (DP-1/DP-2/HDMI-A-1)
      ];
      stealth = {
        enable = true; # Patched QEMU + KVM RDTSC/CPUID/APERF spoofing
        smbios = {
          manufacturer = "ASUSTeK COMPUTER INC.";
          product = "ROG CROSSHAIR X870E HERO";
          biosVendor = "American Megatrends Inc.";
          biosVersion = "2101";
          serial = "M90284371500138"; # Fabricated — realistic ASUS serial format
          # Match actual installed RAM
          memory = {
            manufacturer = "G.Skill International";
            inherit (site.hosts.ryzen-9950x3d.vfio.ram) partNumber;
            speed = 6000;
            size = 16384; # 16GB per DIMM
            count = 2; # 2 × 16GB = 32GB
          };
          # Match 9950X3D cache topology
          cache = {
            l1 = 512;
            l2 = 8192; # 8MB L2
            l3 = 98304; # 96MB L3 (V-Cache CCD0 + standard CCD1)
          };
        };
        edid =
          let
            hw = site.hosts.ryzen-9950x3d.vfio;
          in
          {
            manufacturer = "DEL";
            modelAbbrev = "DEL     ";
            inherit (hw.monitor) model;
            inherit (hw.monitor) serial;
            productCode = "0xa161";
            dpi = 102;
            week = 18;
            year = 2021;
          };
        disk.model = site.hosts.ryzen-9950x3d.vfio.disk.model;
        disk.opticalModel = site.hosts.ryzen-9950x3d.vfio.disk.opticalModel;
        # Match actual motherboard ACPI
        acpiOem = {
          id = "ASUS  ";
          tableId = "ASUS    ";
        };
        macPrefix = "04:42:1a"; # OUI for this host
      };
      kvmfr = {
        enable = true;
        memoryMB = 32; # 1080p SDR (15MB/frame × 2 = 30MB, 32MB is next power of 2)
      };
      hugepages = {
        enable = true;
        count = 16384; # 16384 × 2MB = 32GB for VM
        size = "2M"; # 2MB pages: reliable dynamic allocation, ~2% vs 1G (Red Hat benchmarks)
      };
      evdev = {
        enable = true;
        keyboardPath = "/dev/input/by-id/usb-Ducky_Ducky_One_X_Mini_Wireless-event-kbd";
        mousePath = "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse";
        # Toggle host/guest: press both Ctrl keys simultaneously (grab_all=on)
      };
      # Windows 11 Gaming VM
      # GPU passthrough: RX 9070 XT drives all 3 monitors (DP-1, DP-2, HDMI-A-1)
      # When VM starts: all monitors on the 9070 XT switch to Windows automatically
      # When VM stops: GPU returns to host, monitors show Linux again
      # Host management while VM runs: SSH, or plug a monitor into motherboard HDMI-A-3 (iGPU)
      # Looking Glass: view VM output on iGPU display without separate monitor
      vms.win11 = {
        uuid = "f298e20c-32ad-4921-87f0-164a211125c9";
        memory.count = 32;
        vcpu = {
          count = 16;
          # CCD0 (V-Cache, 96MB L3) — maximum gaming performance
          # Physical cores 0-7 + SMT threads 16-23 share the 96MB L3 cache
          # CCD1 (cores 8-15, 24-31) stays for host background tasks
          pinning = [
            0
            1
            2
            3
            4
            5
            6
            7
            16
            17
            18
            19
            20
            21
            22
            23
          ];
          # Pin QEMU emulator threads to CCD1 (host cores, not VM cores)
          emulatorPin = "8-9";
          # Pin IO thread to dedicated CCD1 core
          iothreadPin = "10";
        };
        # NVMe passthrough: Windows NVMe at 04:00.0 (nvme1n1, no Linux mounts)
        # NOT 05:00.0 — that's the Linux boot drive (nvme0n1, /boot + cryptroot)!
        # Windows sees its real Samsung 9100 PRO — existing install boots directly
        pciPassthrough = [ "0000:04:00.0" ]; # Samsung 9100 PRO 2TB (Windows NVMe)
        # Unmount the Windows partition before NVMe passthrough, remount after VM stops
        mountsToUnmount = [ "/mnt/Windows SSD" ];
        # ASUS SupremeFX onboard audio (internal USB, 0b05:1b7c)
        # Optical out → GoXLR input, so VM audio mixes with Linux audio on GoXLR
        usbPassthrough = [
          {
            vendorId = 2821; # 0x0b05 ASUS
            productId = 7036; # 0x1b7c SupremeFX
          }
        ];
        gpu = {
          # Testing mode: emulated QXL/SPICE via virt-manager (safe, no GPU passthrough)
          # Production: switch to "passthrough" — hook verifies iGPU display before unbinding
          mode = "emulated";
          pciAddress = "0000:03:00.0"; # RX 9070 XT VGA (IOMMU Group 16)
          audioAddress = "0000:03:00.1"; # RX 9070 XT Audio (IOMMU Group 17)
          # Why: dual-GPU host, iGPU (7c:00.0, card0) drives the console + KWin.
          # Only the dGPU (03:00.0, card1) is passed through. The dGPU holds
          # no vtcon/efi-framebuffer attachment, so the single-GPU unbind dance
          # (chvt 3 → vtcon unbind → efi-fb unbind) would blank the iGPU display
          # and cause a host black-screen. KWIN_DRM_DEVICES=card0 + the
          # fallback-display + process-abort safety checks already guarantee
          # the dGPU carries no open DRM contexts when passthrough begins.
          releaseConsole = false;
        };
        # CCD0 = 8c/16t with 96MB V-Cache → spoof as Ryzen 7 9850X3D
        cpuIdentity = {
          modelId = "AMD Ryzen 7 9850X3D 8-Core Processor";
          maxSpeed = 5600; # 9850X3D boost clock
          currentSpeed = 4700; # 9850X3D base clock
        };
      };
    };

    # --------------------------------------------------------------------------
    # Tuning
    # --------------------------------------------------------------------------
    tuning = {
      performance = {
        enable = true;
        governor = "powersave";
        ananicy = true;
        irqbalance = false; # scx_bpfland handles core affinity via L3/CCD-aware scheduling
        scx = {
          enable = true;
          scheduler = "scx_bpfland";
          extraArgs = [
            "-m"
            "auto"
          ];
          # scx_bpfland is correct for dual-CCD X3D: L3/LLC-aware scheduling
          # keeps tasks cache-local per CCD. scx_lavd assumes single-CCX and
          # has two open bugs on 6.19: kernel panic (scx#3474) + EPERM attach
          # failure (scx#3413). Revisit when both fixed AND lavd gains
          # asymmetric-CCD awareness.
        };
      };
      sysctls.enable = true; # BBR, CAKE, tcp_fastopen, max_map_count, etc.
      cachyos = {
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
        amdgpuGcnCompat.enable = false; # Not needed for RX 9070 XT (RDNA 4)
      };
    };

    diagnostics.turbostat.enable = true; # Zen 5 per-core freq + C-state + thermal monitoring
  };

  # ============================================================================
  # Gaming Configuration (Steam + Gamemode — NixOS system-level only)
  # ============================================================================
  myModules.gaming = {
    steam = {
      enable = true;
      gamescope = true; # (default)
    };
    rocksmith.enable = true;
    gamemode = {
      enable = true;
      gpuDevice = 1; # RX 9070 XT = card1 (gpu1 in btop)
      renice = 0; # Disabled — ananicy-cpp handles process priorities globally
      ioprio = "off"; # Disabled — ananicy-cpp manages IO priority
      desiredgov = "performance"; # EPP hint: powersave→performance (modest boost on amd_pstate active)
      x3dMode = {
        desired = "cache"; # Gaming: prefer V-Cache CCD0 (96MB L3)
        default = "frequency"; # Non-gaming: prefer high-clock CCD1
      };
      pinCores = "yes"; # Auto-detect and pin game to V-Cache CCD
    };
  };

  # ============================================================================
  # NVMe I/O tuning — cache-local completion + deeper queues
  # ============================================================================
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/rq_affinity}="2", ATTR{queue/nr_requests}="2048"
  '';

  # ============================================================================
  # System & Localization
  # ============================================================================
  system.stateVersion = "26.05";

  networking.hostName = "ryzen-9950x3d";
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
  # Boot Configuration
  # ============================================================================
  boot = {
    # Note: btrfs already handled by filesystems.nix (enableAll)
    # Note: AMD kernel modules (amdgpu, kvm-amd) in cpu-amd.nix / gpu-amd.nix
    # Note: Sensor modules (zenpower, ryzen_smu, nct6775, it87, msr) in myModules.sensors.*
    #
    # NCT6799 Super I/O fan header mapping (ASUS ROG Crosshair X870E Hero):
    #   fan1 / pwm1  = CPU_FAN   → Arctic Liquid Freezer III radiator fans (~1036 RPM)
    #   fan2 / pwm2  = CPU_OPT   → Empty
    #   fan3 / pwm3  = CHA_FAN1  → Chassis fan (~1333 RPM)
    #   fan4 / pwm4  = CHA_FAN2  → Chassis fan (~1309 RPM)
    #   fan5 / pwm5  = CHA_FAN3  → Chassis fan (~1041 RPM)
    #   fan6 / pwm6  = CHA_FAN4  → Empty
    #   fan7 / pwm7  = W_PUMP+   → Arctic Liquid Freezer III pump (~2789 RPM, always full)
    #   (VRM contact frame fan is SATA-powered — not visible to hwmon)
    loader.timeout = lib.mkForce 10;
    blacklistedKernelModules = [
      "acpi_pad" # Forces CPU idle states — counterproductive on performance desktop
      "mac_hid" # macOS HID emulation — not needed
      "mousedev" # Legacy mouse device — not needed on Wayland
      "eeepc_wmi" # ASUS Eee PC WMI — loaded via ASUS WMI chain, not needed
    ];
  };

  # ============================================================================
  # YeetMouse Acceleration Settings
  # ============================================================================
  # Single source of truth for mouse acceleration parameters.
  # The upstream driver.nix applies these to sysfs via udev on any HID mouse connect.
  # G502 HWDB (flat libinput profile) is handled by myModules.yeetmouse.devices.g502.
  hardware.yeetmouse = {
    sensitivity = 0.5; # Match Raw Accel Windows (0.5)
    # sensitivity = 0.3125; # Match Raw Accel Windows (500/1600)
    rotation = {
      angle = 0.0;
    };
    mode.jump = {
      # acceleration = 1.5;
      # midpoint = 7.0
      acceleration = 2.0;
      midpoint = 7.8;
      useSmoothing = false;
      exponent = 0.00;
    };
  };

  # ============================================================================
  # Nix Daemon — 64GB RAM + NVMe + wired ethernet
  # ============================================================================
  nix.settings = {
    download-buffer-size = 12 * 1024 * 1024 * 1024; # 12 GiB
    http-connections = 50; # Saturate gigabit for parallel substituter downloads
    fsync-store-paths = true; # Desktop has no battery — survive power loss
  };

  # ============================================================================
  # Filesystems
  # ============================================================================
  # Force tmpfs over any @tmp BTRFS subvolume from hardware-configuration.nix
  fileSystems."/tmp" = {
    device = lib.mkForce "tmpfs";
    fsType = lib.mkForce "tmpfs";
    options = lib.mkForce [
      "mode=1777"
      "noatime"
      "noexec"
      "nosuid"
      "nodev"
      "size=16G"
    ];
  };

  # ============================================================================
  # Specialisation — VFIO-safe boot (iGPU only)
  # ============================================================================
  # Pick "ryzen-9950x3d-vfio" at the systemd-boot / GRUB menu BEFORE starting the
  # Windows VM. Restricts KWin to iGPU so the dGPU can be unbound cleanly without
  # tripping KDE Bug 515835 (wl_output race that kills Wayland clients).
  # Why: avoids full Plasma crash on VM start while keeping dual-GPU display
  # normally so main monitors (DP-1, DP-2 on RX 9070 XT) work without workaround.
  specialisation.vfio.configuration = {
    myModules.vfio.sessionGpuDevices = lib.mkForce [
      "/dev/dri/card0" # iGPU only — safe for VFIO passthrough
    ];
  };
}
