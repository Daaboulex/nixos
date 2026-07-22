# ryzen-9950x3d — NixOS host config for Ryzen 9950X3D desktop (Zen 5, RX 9070 XT).
{
  config,
  pkgs,
  inputs,
  lib,
  site,
  myLib,
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
      loader = {
        enable = true;
        systemdBoot.enable = true;
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

      # Off: adopt only with the runtime-state-free /etc contract the
      # module asserts (declarative password, pinned machine-id, relocated
      # host keys), via nrb --boot + reboot.
      etcOverlay.enable = false;

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
          "iommu.strict=1" # Synchronous IOTLB invalidation (closes 2024 deferred-invalidation CVE)
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
          #"amdgpu.cwsr_enable=0" # CWSR (compute wave save/restore) off — works around a GPU hang/reset during ROCm ML training on the 9070XT. Seemed to not work may be false positive.
          "cma=256M" # Contiguous DMA: ath12k WiFi (WCN785x QMI firmware) + USB-audio buffers. 64M exhausted (CmaFree~0) → starved USB-audio (GoXLR/SupremeFX) DMA → retry-thrash stalled their shared bus (mouse hitch).
        ];
        cachyos = {
          cpusched = "bore"; # BORE compiled into kernel as fallback; the scx scheduler overlays it via BPF when loaded
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
        inherit (site.hosts.ryzen-9950x3d.ssh.remoteBuilder) authorizedKeys;
      };
      client.enable = false; # desktop doesn't offload — it's the builder
    };

    # --------------------------------------------------------------------------
    # Users
    # --------------------------------------------------------------------------
    users = {
      enable = true;
      # Off until user-password.age exists in the site registry (see the
      # macbook overlay migration; this host follows the same contract).
      passwordFromSite = false;
    };

    # --------------------------------------------------------------------------
    # Storage
    # --------------------------------------------------------------------------
    storage = {
      filesystems = {
        enable = true;
        enableLinux = true;
        enableWindows = true;
        enableMac = true;
        enableOptical = true;
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
      # Kept ON (unlike macbook): Sunshine enables avahi for Moonlight client
      # discovery, so it can't be turned off here. The services-avahi module's
      # denyInterfaces=wg0-mullvad keeps advertising off the VPN tunnel, so
      # .local stays LAN-only. Resolved's per-link mDNS (multicastDns) is NOT
      # usable on this host — it would need :5353, which avahi holds.
      avahi.enable = true; # mDNS / zeroconf — resolves .local hostnames on LAN
      cups.enable = true;
      earlyoom = {
        enable = true;
        memoryThreshold = 5; # (default)
        swapThreshold = 10; # (default)
      };
      geoclue.enable = true; # Night light location
      mullvad = {
        # Same wg-userspace-fallback trap as macbook: if the kernel WireGuard
        # module isn't pre-loaded, mullvad-daemon falls back to userspace and
        # auto-locks traffic (`Failed to set IPv6 address (ENOENT)`).
        # Daaboulex/mullvad-vpn-nix@41ba6ce loads the kmod + orders the daemon
        # after systemd-modules-load to prevent it.
        # `tunnel.ipv6 = false` kept as defense-in-depth: ISP has no IPv6
        # routing anyway, and a future kernel/hardening change that drops
        # the WG kmod would re-trigger the original bug if v6-in-tunnel
        # were enabled. Belt + suspenders.
        enable = true;
        # Personal policy — keep identical to macbook-pro-9-2/default.nix.
        # Mullvad's `lockdown_mode` IS the kill switch (one field, same thing).
        settings = {
          # ── daemon-level toggles ──
          # Manual-connect policy: the tunnel comes up only on request.
          # Accepted trade-off: until connected, DNS + apps use the real
          # IP. `lan = true` keeps local subnet devices (printer, phone
          # tethering over USB — NOT WiFi tether) reachable.
          autoConnect = false;
          lockdownMode = false; # kill switch OFF (intentional) — clearnet survives a tunnel drop
          lan = true; # local subnet still reachable (printer, LAN peers)
          betaProgram = false;
          updateDefaultLocation = false;
          # ── DNS blockers — ACTIVE (Mullvad's in-tunnel filter tier) ──
          # When tunnel is up, Mullvad overrides systemd-resolved
          # upstream to 100.64.0.23 (in-tunnel). These block* flags
          # decide which categories Mullvad returns NXDOMAIN for.
          # Portmaster's filter lists also block at the connection
          # level (independent layer, not DNS-based).
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
      splitTunnel.enable = true; # On-demand split-tunnel VPN -- internal files + mail only
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
        enable = false; # disabled: stale DBs + unfinished cross-CLI symlink arch; ssh+rsync instead
        relaysEnabled = true;
        globalAnnounceEnabled = true;
        devices.macbook-pro-9-2.id = site.hosts.macbook-pro-9-2.syncthing.deviceId;
        devices.pixel-9-pro.id = site.hosts.pixel-9-pro.syncthing.deviceId;
        folders = {
          documents = {
            path = "/home/user/Documents";
            devices = [
              "macbook-pro-9-2"
              "pixel-9-pro"
            ];
          };
          ai-context = {
            path = "/home/user/.ai-context";
            devices = [
              "macbook-pro-9-2"
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
        inherit (site.hosts.ryzen-9950x3d.ssh) trustedKeys;
        extraIgnoreSubnets = [ site.network.subnet ]; # loopback baseline is the ssh module default
      };
      agenix = {
        enable = true;
        # identityPaths uses host SSH key by default
        # split-tunnel VPN client PKI (consumed by myModules.services.splitTunnel).
        # The login password is NOT here -- it is agent-owned in KWallet.
        secrets.split-tunnel-ca = { };
        secrets.split-tunnel-cert = { };
        secrets.split-tunnel-key = { };
        secrets.split-tunnel-pass = { }; # VPN login password (env SPLIT_TUNNEL_PASS)
        # secrets.user-password = { }; # uncomment with users.passwordFromSite (the ceremony creates the blob first)
      };
      portmaster = {
        enable = false;
        notifier = true; # System tray icon (autostart)
        autostart = true; # Start on boot
        # MULLVAD + PORTMASTER STACK
        #
        # DNS topology (with `filter/dnsQueryInterception=false`):
        #   app DNS → 127.0.0.53 (systemd-resolved stub)
        #     → systemd-resolved upstream: Mullvad DoT 194.242.2.3:853
        #     → when tunnel up: Mullvad overrides upstream to 100.64.0.23
        #       (plaintext in-tunnel, hence dnsOverTls=opportunistic)
        #     → Mullvad's ad/tracker/malware filter tier applied server-side
        #   app TCP/UDP
        #     → Portmaster nfqueue (per-app firewall, filterlists, rules)
        #     → wg0-mullvad → Mullvad relay
        #
        # Portmaster's own resolver is configured (dns/nameservers below)
        # but only used for Portmaster's internal lookups (filter lists,
        # app reputation). App DNS does NOT flow through Portmaster when
        # dnsQueryInterception=false.
        #
        # Why `dnsQueryInterception=false` is load-bearing:
        # Portmaster's packet_handler.go:467 rewrites every outbound :53
        # packet to its internal resolver — GLOBAL, ignores per-profile
        # allow rules. With the in-tunnel resolver (100.64.0.23), pre-
        # tunnel queries have no route → timeout → mullvad-daemon can't
        # resolve api.mullvad.net → deadlock. Disabling lets mullvad-
        # daemon bootstrap DNS go direct (Mullvad's nftables kill-switch
        # exempts its own daemon).
        #
        # Trade-off: Portmaster's self-check fails → "Detected
        # Compatibility Issue" notification (cosmetic, unavoidable).
        # Portmaster loses per-process DNS attribution. Both are
        # acceptable given the alternative is a DNS deadlock.
        #
        # Ref: service/firewall/packet_handler.go:467-483  (interception)
        # Ref: service/resolver/resolve.go:395,446         (offline fail)
        # Ref: service/compat/selfcheck.go                 (self-check)
        # Ref: wiki.safing.io/en/Portmaster/App/Compatibility/Software/MullvadVPN
        # These keys ALL live in forceSettings because the wrong value on
        # any of them breaks the Mullvad+Portmaster stack. UI edits are
        # reverted on next boot — intentional.
        forceSettings = {
          # Portmaster resolves a set value only when the option's
          # ReleaseLevel <= the global level (base/config/get.go); the
          # interception toggle below is ReleaseLevel=Experimental, so
          # without this line its `false` validates, persists, and shows
          # as set in the UI while the engine silently runs the default
          # (true). "beta" is not enough; unknown strings fall back to
          # "stable" with no warning.
          "core/releaseLevel" = "experimental";
          # Do NOT redirect outbound :53 to Portmaster's resolver.
          # Required to break the Mullvad bootstrap deadlock, and for the
          # split-tunnel DNS chain (resolved -> alias-rewriting dnsmasq ->
          # office DNS), whose loopback + in-tunnel hops interception
          # would hijack into "no compliant resolvers" blocks.
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
            "dot://dns.quad9.net?ip=9.9.9.9&name=Quad9&blockedif=empty"
            "dot://dns.quad9.net?ip=149.112.112.112&name=Quad9&blockedif=empty"
            "dot://dns.mullvad.net?ip=194.242.2.2&name=MullvadUnfilteredDoT&blockedif=empty"
          ];
          # Portmaster's internal resolver ignores DHCP-assigned DNS.
          # Not load-bearing for app DNS (apps use systemd-resolved),
          # but prevents Portmaster's own lookups from leaking to ISP.
          "dns/noAssignedNameservers" = true;
          # Reject plaintext DNS in Portmaster's internal resolver.
          "dns/noInsecureProtocols" = true;
          # SPN and Mullvad are mutually exclusive — both reroute all
          # traffic. SPN defaults to false but lock it to prevent
          # accidental UI toggle.
          "spn/enable" = false;
        };
      };
      # Preserve Mullvad's WireGuard fwmark (0x6d6f6c65) from Portmaster's
      # CONNMARK --restore-mark. Without this, fresh Mullvad connections
      # get their policy-routing mark zeroed, encapsulated packets loop
      # back into wg0-mullvad, and the tunnel can't reach its relay until
      # Portmaster is paused. See parts/security/portmaster-mullvad-compat.nix.
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
        # multicastDns stays "no" (default): resolved-as-mDNS-responder needs
        # :5353, but Sunshine forces avahi on (see services.avahi below), so
        # avahi owns mDNS here. avahi's denyInterfaces=wg0-mullvad keeps it
        # LAN-only — no tunnel leak.
        #openPorts = [24727]; # (default)
        #openPortRanges = [{ from = 24727; to = 24727; }]; # (default)
        # nameservers use module default (Mullvad adblock DoT)
        # Why opportunistic: Mullvad overrides systemd-resolved upstream
        # to plaintext 100.64.0.23 inside the tunnel. Strict DoT would
        # SERVFAIL on that plaintext upstream during tunnel transitions.
        dnsOverTls = "opportunistic";
        # Wired uplink to enslave into br0 when a VFIO profile enables lanBridge
        # (passthrough VMs then get real LAN IPs); inert in normal (lanBridge off).
        lanBridge.uplink = "enp14s0";
        vpnPlugins = [ pkgs.networkmanager-openvpn ]; # KDE OpenVPN import (25.11 dropped the default plugins)
      };
      pipewire = {
        enable = true;
        lowLatency = true;
        extraLadspaPackages = [ pkgs.deepfilternet ];
      };
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      riftCv1.enable = true; # Monado/OpenHMD on the host 9070 XT (VFIO profiles force it off)
      graphics = {
        enable = true;
        enable32Bit = true; # (default)
        # Intel GPU: not imported on this host (see flake-module.nix)
        # NVIDIA GPU: proprietary driver via myModules.hardware.gpuNvidia (compute mode); mesa stays AMD-only
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
        lact.configFile = ./lact-config.yaml; # declarative LACT v6 tune (AMD undervolt/power-cap + 1660S clocks)
        initrd.enable = true; # Load amdgpu early (faster display init)
        enablePPFeatureMask = true; # OverDrive (LACT) + GFXOFF-off (RDNA stability) via the PowerPlay mask
        drmDebug = false; # Was destroying ALL boot logs (~800 msg/sec overflows kmsg ring buffer)
        disableHDCP = false; # HDCP enabled (was disabled for RDNA 4 handshake debugging)
        openCL = true; # (default) — RustiCL radeonsi driver
      };
      gpuNvidia = {
        enable = true;
        profile = {
          # Secondary GPU: CUDA / NVENC / local-LLM compute, and in the normal profile it
          # scans out the portrait monitor (re-cabled to its DP-5). The AMD renders the
          # desktop, so NO PRIME — pick a GPU per-app via env vars (DRI_PRIME /
          # __NV_PRIME_RENDER_OFFLOAD). The 1660S is PASSED to a VM in vfio-dynamic, which
          # disables this whole driver (see that spec) so the card sits driverless for
          # libvirt to bind vfio-pci. We never live-unbind a loaded nvidia driver:
          # persistenced + nvidia-drm modeset hold the device, so a live unbind would fail
          # — vfio-dynamic disables it instead.
          mode = "compute";
          # "latest" = 610.43.02 (NVIDIA New-Feature / beta-class branch) is the driver
          # whose upgrade introduced the periodic Wayland micro-stutter on the 1660S-driven
          # portrait. "production" = NVIDIA's conservative branch (595.80 in this lock), which is still
          # >= the 595.71.05 that carries the kernel-7.1 linux/of_gpio.h build guard, so it
          # builds here (the older 595.45.04 beta does not). Revert to "latest" only if
          # production fails to build, or if the stutter proves structural (GSP / multi-GPU
          # power-state) rather than branch-specific.
          packageChannel = "production";
          persistenced = true; # keep initialized for CUDA/LLM responsiveness (normal only; vfio-dynamic disables nvidia)
          settings = true; # nvidia-settings GUI
          videoAcceleration = true; # NVENC/NVDEC
          nvidiaBusId = "PCI:5:0:0"; # GTX 1660S @ 05:00.0
          intelBusId = ""; # no Intel iGPU
          # FULL nvidia feature set in normal; inert in vfio-dynamic where the driver is
          # disabled. Turns on the NVreg block:
          #   NVreg_PreserveVideoMemoryAllocations=1 — VRAM survives suspend/hibernate
          #   NVreg_TemporaryFilePath=/var/tmp        — save-state on disk, NOT the default
          #     /tmp (tmpfs on this host → would burn RAM and break hibernate)
          #   NVreg_EnableGpuFirmware=1               — GSP firmware (the open module requires it)
          #   NVreg_DynamicPowerManagement=0x00       — RTD3 disabled. Verified inert on this HW:
          #     /proc reports "Runtime D3: Disabled by default" (Turing + open + GSP, desktop slot),
          #     and the 1660S already idles to P8 ~17W via intrinsic PowerMizer gating. RTD3 is a
          #     laptop feature; enabling it would only risk display-loss if it ever engaged on the host.
          nvregEnable = true;
        };
      };
      cpuAmd = {
        enable = true; # AMD CPU optimizations (pstate, prefcore, kvm, microcode)
        pstate = {
          enable = true; # (default)
          mode = "active"; # (default)
        };
        prefcore.enable = true; # (default)
        x3dVcache = {
          enable = true; # Dual-CCD 3D V-Cache optimizer (amd_3d_vcache driver). Governs idle CCD placement on BORE/CFS; largely muted under scx, which does its own L3/CCD-aware placement.
          mode = "frequency"; # Idle default = high-clock CCD1 (compute/general); gamemode flips to cache + pins the game to the V-Cache CCD0 during play.
        };
        kvm.enable = true; # (default) — KVM virtualization
        updateMicrocode = true; # (default)
      };
      # Intel CPU: not imported on this host (see flake-module.nix)
      # performance is configured by tuning.performance below
      power = {
        enable = true;
        tlp = false; # desktop -- no battery/AC profiles
        powerProfilesDaemon = true; # KDE power-profile selector; sets EPP on amd-pstate-epp, composes with scx_lavd (no governor conflict)
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
        # Stable per-GPU DRM aliases (/dev/dri/by-gpu/{igpu,amd,nvidia}) for cardN-free
        # KWIN_DRM_DEVICES selection. RE-VERIFY these PCI BDFs after any hardware change.
        gpuAliases = {
          igpu = "0000:7c:00.0"; # Raphael iGPU
          amd = "0000:03:00.0"; # RX 9070 XT
          nvidia = "0000:05:00.0"; # GTX 1660 SUPER
        };
        monitors = {
          main = {
            connector = "DP-1";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239757;
            };
            # DP-1 owns the layout origin (0,0): fullscreen / XWayland (Proton) games
            # spawn at the top-left of the combined screen space, so the origin output
            # must be this 9070 XT head -- otherwise games open on the portrait (1660S).
            position = {
              x = 0;
              y = 0;
            };
            priority = 1;
            vrr = "automatic";
            inherit (site.hosts.ryzen-9950x3d.displays.monitors.main) edidHash edidIdentifier uuid;
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":0.5},{"width":0.5}]}'';
          };
          portrait = {
            # Re-cabled from the 9070 XT's DP-2 onto the 1660S's DisplayPort (KMS DP-5) --
            # the 1660S is in sessionGpuDevices so KWin drives it. EDID/uuid below come from
            # the panel as the 1660S reports it over DP (differs from the 9070 XT DP-2 EDID).
            connector = "DP-5";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239761;
            };
            # Logical RIGHT of DP-1 although physically on the LEFT: DP-1 must keep the
            # (0,0) origin (above) and the layout permits no negative coordinates, so this
            # head sits past DP-1's right edge -- cross the main monitor's right edge to reach it.
            position = {
              x = 1920;
              y = 0;
            };
            priority = 2;
            rotation = "left";
            vrr = "automatic";
            inherit (site.hosts.ryzen-9950x3d.displays.monitors.portrait) edidHash edidIdentifier uuid;
            tiling.layout = ''{"layoutDirection":"vertical","tiles":[{"height":0.333},{"height":0.334},{"height":0.333}]}'';
          };
          # Same portrait Dell as DP-2, but on the 1660S's HDMI-A-2 in the VFIO profiles
          # (the 9070 XT that drives DP-1/DP-2 is captured by vfio-pci, so those heads go
          # dark and the panel is re-cabled to the 1660S). edidHash/uuid differ from DP-2 —
          # the panel reports a slightly different EDID over HDMI vs DP. Without this entry
          # SDDM + the session default to landscape on this head. Inert in non-VFIO profiles
          # (HDMI-A-2 isn't connected there).
          portrait-vfio = {
            connector = "HDMI-A-2";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239761;
            };
            position = {
              x = 0;
              y = 0;
            };
            priority = 1;
            rotation = "left";
            vrr = "automatic";
            inherit (site.hosts.ryzen-9950x3d.displays.monitors.portrait-vfio) edidHash edidIdentifier uuid;
            tiling.layout = ''{"layoutDirection":"vertical","tiles":[{"height":0.333},{"height":0.334},{"height":0.333}]}'';
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
      utility.enable = true; # (default)
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
      # Host-critical disks — the eval-time guard refuses any VM that passes one in
      # pciPassthrough (typo net; the runtime protectedDiskGuard handles live BDF
      # renumber). 04:00.0 is the LUKS cryptroot (/boot + /, /nix, /home).
      protectedDiskAddrs = [ "0000:04:00.0" ];
      bindMethod = "dynamic"; # inert at base (normal has no passthrough); VFIO specs force "static"
      # Stealth OVMF (SecureBoot + MS-keys varstore). SMM + secure pflash are
      # injected via extraQemuArgs below (NixVirt cannot express <smm/> or
      # <loader secure='yes'/> natively).
      ovmf.package = pkgs.ovmf-stealth.fd;
      # ACS override is deliberately NOT set here. It fakes PCIe ACS isolation (a
      # real security downgrade — see the option's SECURITY WARNING), and the
      # normal profile passes nothing, so it MUST boot without it. It is enabled
      # ONLY in the two VFIO specialisations below, each of which passes the
      # Windows NVMe (0f:00.0) — that device shares IOMMU group 22 (chipset PCIe
      # switch) with the NICs / WiFi / 990 EVO / SATA, and ACS override splits the
      # group so only 0f is handed to the guest. The NVMe can't move to the clean
      # CPU-lane slot (group 18 shares lanes with PCIEX16_2 → would disable the 2nd
      # GPU). cachyos-lto carries the patch (verified: pcie_acs_override in-kernel).
      # KWin render-GPU selection (KWIN_DRM_DEVICES), by STABLE PCI aliases (gpuAliases →
      # /dev/dri/by-gpu/*), NOT cardN: cardN renumbers when a GPU is captured by vfio-pci
      # (a passed GPU loses its DRM node), which would point KWIN_DRM_DEVICES at the wrong
      # / a missing card and trip an SDDM login loop. The aliases are ':'-free so they
      # survive the KWIN_DRM_DEVICES ':' separator. ORDER = priority: the FIRST device is
      # the primary render GPU. Normal lists the 9070 XT first so it renders the desktop it
      # drives (DP-1) natively. The 1660S is INCLUDED so KWin can drive the portrait panel
      # re-cabled to its DisplayPort (DP-5) — secondary scan-out; the 9070 XT stays the render
      # GPU (listed first). The iGPU is a secondary reserve (no monitor cabled). The VFIO
      # specialisations override per profile; under static binding the passed GPU has no
      # alias, so each list names only GPUs that are present.
      sessionGpuDevices = [
        "/dev/dri/by-gpu/amd" # RX 9070 XT (03:00.0) — primary render + DP-1 (main landscape)
        "/dev/dri/by-gpu/nvidia" # GTX 1660S (05:00.0) — drives DP-5 (portrait, re-cabled here)
        "/dev/dri/by-gpu/igpu" # iGPU (7c:00.0) — secondary reserve (mobo HDMI; no monitor cabled)
      ];
      stealth =
        let
          hw = site.hosts.ryzen-9950x3d.vfio;
        in
        {
          enable = true;
          hypervMode = "enlightened";
          hypervVendorId = "Microsoft Hv";
          timing.enable = false;
          cpuidPassthrough.enable = false;
          kvmPvEnforceCpuid = false;
          smbios = {
            inherit (hw.smbios)
              manufacturer
              product
              biosVendor
              biosVersion
              biosDate
              biosRelease
              baseBoardVersion
              baseBoardSerial
              oemStrings
              onboardDevices
              cache
              ;
            memory = {
              inherit (hw.smbios.memory) manufacturer speed;
              inherit (hw.ram) partNumber;
              count = 4;
            };
          };
          edid = {
            inherit (hw.edid)
              manufacturer
              productCode
              dpi
              week
              year
              ;
            inherit (hw.monitor) serial;
          };
          disk = {
            inherit (hw.disk) model serial opticalModel;
          };
          inherit (hw) acpiOem;
          inherit (hw) macPrefix;
          tpm = {
            inherit (hw.tpm)
              manufacturer
              model
              firmwareVersion
              platformManufacturer
              platformModel
              ;
          };
        };
      kvmfr = {
        # Looking Glass DISABLED globally — the ivshmem (1af4 Red Hat) PCI device it
        # adds is a detectable VM tell, and both VMs are max-stealth. View a running
        # VM by switching the monitor input instead (both dGPUs are cabled to the monitors).
        enable = false;
        memoryMB = 32; # (unused while disabled)
      };
      hugepages = {
        enable = true;
        count = 16384; # 16384 × 2MB = 32GB for VM
        size = "2M"; # 2MB pages: reliable dynamic allocation, ~2% vs 1G (Red Hat benchmarks)
      };
      evdev = {
        enable = true;
        keyboardPath = "/dev/input/by-id/usb-Ducky_Ducky_One_X_Mini_Wireless-event-kbd";
        extraKeyboardPaths = [
          "/dev/input/by-id/usb-Ducky_Ducky_One_X_Mini_Wireless-if02-event-kbd"
        ];
        mousePath = "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse";
      };
      # win11-amd — gaming VM (RX 9070 XT → CCD0 V-Cache). Defined here enable=false;
      # specialisation.vfio-dynamic flips it on with gpu.libvirtManaged=true, so libvirt
      # binds the 9070 XT to vfio-pci at VM start and rebinds amdgpu on stop (no boot
      # capture). WIP: the AMD driver does not yet install on Navi 48 — see the
      # 9070xt-vfio-corruption memory note.
      vms.win11-amd = {
        enable = false; # Normal/Default = no VM; enabled only by specialisation.vfio-dynamic
        uuid = "f298e20c-32ad-4921-87f0-164a211125c9";
        # NAT via virbr0 (libvirt default network). Bridge mode needs enp14s0
        # (Realtek 8126 5G) cabled; the host runs on eno1 (Intel I226).
        network.type = "nat";
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
        # NVMe passthrough: Windows = nvme0n1 at 0f:00.0 (Samsung 9100 PRO 2TB,
        # NTFS: ESP+MSR+Windows+WinRE — no Linux mounts; the existing install
        # boots directly). NOT 04:00.0 — that's the OTHER, identical 9100 PRO
        # (nvme1n1) holding /boot + the LUKS cryptroot (/, /nix, /home). The two
        # 9100 PROs differ only by serial+BDF, so a bus renumber (e.g. adding the
        # NVIDIA card — which is what last inverted these) can swap them; the
        # protectedDiskGuard refuses any BDF backing a host FS as the safety net.
        # RE-VERIFY BDFs (lspci + lsblk) after any hardware change.
        #
        # 0f shares IOMMU group 22 (chipset PCIe switch) with the NICs / 990
        # EVO / SATA. myModules.vfio.acsOverride (set in the VFIO specialisations via _common-vfio.nix) splits the group
        # so ONLY this NVMe is passed; everything else stays on the host. See
        # that option's SECURITY note re: the faked isolation + the 990 EVO.
        pciPassthrough = [ "0000:0f:00.0" ]; # Windows NVMe (Samsung 9100 PRO 2TB, nvme0n1)
        # Unmount the Windows partition before NVMe passthrough, remount after VM stops
        mountsToUnmount = [ "/mnt/Windows-SSD" ];
        # Audio BRIDGE, not a peripheral grab: the VM outputs to the SupremeFX onboard
        # audio, whose optical S/PDIF out feeds the host GoXLR as an input — so VM audio is
        # mixed + controlled on the GoXLR. GoXLR + Stream Deck are NOT passed; they stay on
        # the HOST (goxlr-utility / streamcontroller). Keyboard + mouse reach the VM via evdev.
        # (SupremeFX placement amd-vs-nvidia is the open audio question — see plan §U.)
        usbPassthrough = [
          {
            vendorId = 2821; # 0x0b05 ASUS
            productId = 7036; # 0x1b7c SupremeFX onboard audio (optical → host GoXLR)
          }
        ];
        gpu = {
          # Active only in specialisation.vfio-dynamic (enable=false at base).
          mode = "passthrough";
          pciAddress = "0000:03:00.0"; # RX 9070 XT VGA (IOMMU Group 16)
          audioAddress = "0000:03:00.1"; # RX 9070 XT Audio (IOMMU Group 17)
          # 9070 XT vendor:device IDs (VGA 1002:7550 + HDMI/DP audio 1002:ab40) for
          # bindMethod=static capture. UNUSED under vfio-dynamic (gpu.libvirtManaged binds
          # via libvirt, no vfio-pci.ids) — kept as the card's identity / for a static profile.
          staticIds = [
            "1002:7550"
            "1002:ab40"
          ];
          # Clean VBIOS override — the 9070 XT is the board's BIOS-primary GPU
          # (boot_vga=1), so its option ROM is shadowed/init'd at host POST and the
          # guest reads a dirty image → can't bring up the display engine (black
          # screen on every output). This is a pristine pre-shadow dump (NAVI48 XTX,
          # ATOMBIOS VER023.008.000.068, UEFI GOP REV 003.009.001.023.008) read off
          # the PCI ROM BAR while the card was on vfio-pci/reset, so OVMF + the guest
          # driver initialise from a clean ROM. Emits <rom file=…/> on the hostdev.
          romFile = "${./vbios/9070xt.rom}";
          # RDNA 4 / Navi 48 REQUIRES the ROM BAR off: the guest AMD driver misreads
          # the ROM BAR and produces green/red framebuffer corruption (see the romBar
          # option in parts/vfio/vms.nix). libvirt still loads the clean romFile for
          # OVMF (<rom bar='off' file='…'/>) — the file gives a pristine image while
          # the BAR the driver mis-parses is hidden from the guest.
          romBar = false;
          # BAR2 clamp (the Navi Code-43 lever, gpu.bar2ResizeMB) is NOT set here:
          # it needs gpu.dynamicBind, mutually exclusive with the libvirtManaged
          # path vfio-dynamic uses. The observed failure on this card is the
          # green/red corruption, fixed by romBar=false above; the BAR2 clamp
          # addresses the separate Code-43 mode. The option stays available in
          # parts/vfio/vms.nix for a future dynamicBind profile if Code-43 appears.
        };
        # win11-amd gets CCD0 = 8c/16t (the 96MB V-Cache CCD — see vcpu.pinning
        # below), so spoof as Ryzen 7 9850X3D — the real 2026 "soft refresh" of
        # the 9800X3D (same 8c + 96MB L3 V-Cache, boost raised +500MHz to
        # 5.6GHz). It matches this chip's V-Cache-CCD0 boost far better than the
        # 9800X3D and sits closest to the host's real 9950X3D. AMD official
        # specs: base 4.7 / boost 5.6 GHz / 96MB L3 — the smbios.cache l3=98304
        # already reflects that V-Cache. Confirm exact SMBIOS Max/Current Speed
        # against `sudo dmidecode -t 4`.
        cpuIdentity = {
          modelId = "AMD Ryzen 7 9850X3D 8-Core Processor";
          maxSpeed = 5600; # 9850X3D max boost 5.6 GHz
          currentSpeed = 4700; # 9850X3D base 4.7 GHz
        };
        extraQemuArgs = [
          "-serial"
          "file:/tmp/windows-serial.log"
          "-d"
          "guest_errors,cpu_reset"
          "-D"
          "/tmp/qemu-guest-errors.log"
          "-debugcon"
          "file:/tmp/ovmf-debug.log"
          "-global"
          "isa-debugcon.iobase=0x402"
        ];
      };

      # Windows 11 security-research sandbox VM (GTX 1660S → CCD1). Defined
      # here (enable=false) so both VMs live at base with identical protections;
      # specialisation.vfio-dynamic flips enable=true.
      vms.win11-nvidia = {
        enable = false;
        uuid = "97d5e852-5b66-4081-9142-9cdd96bb716a";
        # NAT via virbr0 (libvirt default network). Bridge mode needs enp14s0
        # (Realtek 8126 5G) cabled; the host runs on eno1 (Intel I226).
        network.type = "nat";
        memory.count = 32;
        vcpu = {
          count = 16;
          # CCD1: physical cores 8-15 + SMT threads 24-31 (the non-V-Cache CCD)
          pinning = [
            8
            9
            10
            11
            12
            13
            14
            15
            24
            25
            26
            27
            28
            29
            30
            31
          ];
          emulatorPin = "0-1"; # QEMU emulator threads on CCD0 (host side)
          iothreadPin = "2"; # IO thread on a CCD0 host core
        };
        gpu = {
          mode = "passthrough";
          pciAddress = "0000:05:00.0"; # GTX 1660S VGA (IOMMU group 19)
          audioAddress = "0000:05:00.1"; # 1660S HDMI/DP audio
          # 1660S USB-C controller (05:00.2, group 21) + serial (05:00.3). Verify
          # each func's IOMMU group is isolated at deploy — groups can shift when
          # GPU drivers or ACS settings change.
          extraFunctions = [
            "0000:05:00.2"
            "0000:05:00.3"
          ];
          # Captured by vfio-pci.ids at boot under bindMethod=static. All four 1660S
          # functions: VGA + HD-audio + USB 3.1 + USB-C UCSI.
          staticIds = [
            "10de:21c4"
            "10de:1aeb"
            "10de:1aec"
            "10de:1aed"
          ];
          # Clean VBIOS (TU116 — legacy + UEFI GOP image both present). This card is
          # NOT boot_vga, so its ROM isn't shadowed and passthrough works without an
          # override — supplied for symmetry with the 9070 XT and as a Code-43
          # belt-and-suspenders beside kvm-hidden. Read off the PCI ROM BAR.
          romFile = "${./vbios/1660s.rom}";
        };
        # Disk: 0b (the 1 TB PM9C1a) — nvidia uses 0b, amd keeps the 2 TB 0f (both in
        # vfio-dynamic). One mental model, real-NVMe
        # passthrough (max stealth, distinct real disk serial per VM). 0b is NOT a host
        # mount (no fileSystems entry — the prior btrfs is disposable), so nothing to
        # unmount. Plus the GREATHTEK USB controller (7c:00.4, isolated IOMMU grp 34)
        # passed WHOLE so arbitrary devices on its port reach the guest with native
        # hotplug (the 2nd-person swap port) — a hub passed by vendor:product would NOT
        # forward its children. PREREQ (#11): Windows installed on 0b.
        pciPassthrough = [
          "0000:0b:00.0" # Windows NVMe (Samsung PM9C1a 1TB)
          "0000:7c:00.4" # GREATHTEK USB controller (whole-controller passthrough)
        ];
        # Spoof CCD1 as a non-V-Cache Ryzen 7 9700X (8c, 32 MB L3).
        cpuIdentity = {
          modelId = "AMD Ryzen 7 9700X 8-Core Processor";
          maxSpeed = 5500; # 9700X boost
          currentSpeed = 3800; # 9700X base
        };
        cache.l3 = 32768; # 32 MB — CCD1 has no V-Cache (per-VM cache from Step 1)
        cache.assocL3 = 7; # 8-way — CCD1's L3 is non-V-Cache, 8-way (not 16-way V-Cache)
        # Audio bridge: SupremeFX → this VM; its optical S/PDIF out feeds the host GoXLR
        # (the host mixes it while win11-nvidia runs under vfio-dynamic).
        # The GREATHTEK swap-port is the whole-controller PCI passthrough above (NOT a USB
        # hostdev — passing the hub by id would not forward devices plugged into it).
        usbPassthrough = [
          {
            vendorId = 2821; # 0x0b05 ASUS
            productId = 7036; # 0x1b7c SupremeFX onboard audio (optical → GoXLR / 2nd-person)
          }
        ];
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
        irqbalance = false; # scx handles core affinity (L3/CCD-aware placement)
        scx = {
          enable = true;
          scheduler = "scx_lavd";
          extraArgs = [ ];
          # scx_lavd: latency-aware virtual-deadline scheduler. extraArgs MUST
          # stay lavd-valid -- [] selects autopilot (the safe default). NEVER
          # pass bpfland's -m primary-domain flag (lavd rejects it and fails to
          # attach, silently falling back to BORE) nor --performance (it leaks
          # memory). lavd builds per-LLC/per-CCD domains but does NOT steer
          # cache-hungry tasks onto the V-Cache CCD; that preference is left to
          # amd_3d_vcache + gamemode x3dMode.
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
        nvidia.enable = false; # CachyOS nvidia tweaks off — gpu-nvidia module owns the driver; revisit if the 1660S wants CachyOS-specific nvidia kernel/modprobe tuning
        amdgpuGcnCompat.enable = false; # Not needed for RX 9070 XT (RDNA 4)
      };
    };

    diagnostics.nftables.enable = true; # nft CLI -- read the live split-tunnel alias table + firewall (sudo)
    diagnostics.turbostat.enable = true; # Zen 5 per-core freq + C-state + thermal monitoring
  };

  # ============================================================================
  # ============================================================================
  # Gaming Configuration (Steam + Gamemode — NixOS system-level only)
  # ============================================================================
  myModules.gaming = {
    steam = {
      enable = true;
      gamescope = true; # (default)
    };
    proton = {
      enable = true;
      cachyos = pkgs.proton-cachyos-v3;
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
    # Ducky One X Mini (wireless, 3233:001d) — never autosuspend. The keyboard's
    # evdev node must stay live: when it re-enumerates/power-saves, QEMU's held
    # input-linux fd goes stale → "input_linux_event: read: No such device" →
    # the keyboard stops passing to the guest (the mouse keeps working). USB
    # power-control "on" = autosuspend disabled, node stays present.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3233", ATTR{idProduct}=="001d", TEST=="power/control", ATTR{power/control}="on"
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
    # Note: btrfs already handled by filesystems.nix (enableLinux)
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
      "ucsi_ccg" # 1660S VirtualLink USB-C controller (i2c 9-0008 / 05:00.3) — nothing cabled to it; probe always times out (-110) → boot-log noise. Passed-through in nvidia/all profiles anyway.
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
  };

  # nixpkgs default SystemMaxUse = 50M rotates a busy desktop's journal away
  # within a day, leaving nothing to investigate after a crash or regression.
  # 4G keeps weeks of boots on the 2TB NVMe; SystemKeepFree yields to real
  # disk pressure. Storage is persistent (/var/log/journal on @log).
  services.journald.extraConfig = ''
    SystemMaxUse=4G
    SystemKeepFree=4G
  '';

  # ============================================================================
  # Filesystems
  # ============================================================================
  # /tmp is tmpfs; the @tmp subvolume backs /var/tmp (hardware-configuration.nix),
  # so nothing else defines /tmp here.
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=1777"
      "noatime"
      "noexec"
      "nosuid"
      "nodev"
      "size=16G"
    ];
  };

  # Registry name/key pins — hosts the resolver cannot name (mDNS is
  # link-local, never crosses a routed VPN; the DoT resolver bypasses foreign
  # DNS). Every identifying value lives in the private registry.
  networking.hosts = lib.listToAttrs (
    map (e: lib.nameValuePair e.ip e.names) site.network.pins.etcHosts
  );
  programs.ssh.knownHosts = site.network.pins.sshKnownHosts;

  # ── Specialisations (boot entries) ──
  # Each lives in ./specialisations/<name>.nix, auto-wired by readDir (the folder is the
  # manifest — drop a file to add a boot entry; `_`-prefixed files are shared fragments,
  # not specs).
  specialisation = myLib.mkSpecialisations { dir = ./specialisations; };
}
