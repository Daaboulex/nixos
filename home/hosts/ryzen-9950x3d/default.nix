{
  config,
  lib,
  pkgs,
  site,
  ...
}:

{
  imports = [
    ./goxlr
    ./coolercontrol
    ./streamcontroller
  ];

  home.stateVersion = "26.11";

  # Enabled modules (alphabetical). Absence = off (mkEnableOption default).
  myModules.home = {
    android.enable = true;
    antigravity.enable = true;
    anydesk.enable = true;
    archive.enable = true;
    arkenfox.enable = true;
    atuin.enable = true;
    bat.enable = true;
    bluez-tools.enable = true;
    brightnessctl.enable = true;
    btop.enable = true;
    c-cpp.enable = true;
    chafa.enable = true;
    cifs-utils.enable = true;
    claude-code.enable = true;
    cmake.enable = true;
    cod-clients.enable = true;
    codex-cli.enable = false;
    comma.enable = true;
    coolercontrol.enable = true;
    corecycler.enable = true;
    csvlens.enable = true;
    curl.enable = true;
    delta.enable = true;
    dev-dirs.enable = true;
    devenv.enable = true;
    difftastic.enable = true;
    dig.enable = true;
    direnv.enable = true;
    displays.enable = true;
    dmidecode.enable = true;
    duf.enable = true;
    durdraw.enable = true;
    dust.enable = true;
    ethtool.enable = true;
    eza.enable = true;
    fastfetch.enable = true;
    fd.enable = true;
    ffmpeg.enable = true;
    flatpak.enable = true;
    fzf.enable = true;
    gcc.enable = true;
    gdb.enable = true;
    gemini-cli.enable = false;
    ghostty.enable = true;
    git.enable = true;
    glow.enable = true;
    gnumake.enable = true;
    goxlr.enable = true;
    gparted.enable = true;
    gpg.enable = true;
    gtk.enable = true;
    hermes.enable = true;
    heroic.enable = true;
    hexyl.enable = true;
    hwinfo.enable = true;
    hyperfine.enable = true;
    ifuse.enable = true;
    inxi.enable = true;
    iodiag.enable = true;
    iommu.enable = true;
    iotop.enable = true;
    iw.enable = true;
    jq.enable = true;
    kate.enable = true;
    kdotool.enable = true;
    konsole.enable = true;
    lact.enable = true;
    lazygit.enable = true;
    libimobiledevice.enable = true;
    llmfit.enable = true;
    lm-sensors.enable = true;
    lmstudio.enable = true;
    looking-glass.enable = false; # Looking Glass unused — never frame-relay; kvmfr/ivshmem also off
    lsfg-vk.enable = true;
    lshw.enable = true;
    lsof.enable = true;
    mangohud.enable = true;
    mangojuice.enable = true;
    man-pages.enable = true;
    memtest-vulkan.enable = true;
    minicom.enable = true;
    models.enable = true;
    moonlight.enable = true;
    mullvad.enable = true;
    navi.enable = true;
    nano.enable = true;
    neovim.enable = true;
    nil.enable = true;
    nix-github-token.enable = true;
    nix-output-monitor.enable = true;
    nix-prefetch-git.enable = true;
    nix-tree.enable = true;
    node.enable = true;
    ns-usbloader.enable = true;
    nvd.enable = true;
    obsidian.enable = true;
    occt.enable = true;
    okular.enable = true;
    opencode.enable = true;
    pastel.enable = true;
    pciutils.enable = true;
    pi.enable = true;
    piper.enable = true;
    pkg-config.enable = true;
    plasma.enable = true;
    powershell.enable = true;
    powertop.enable = true;
    prismlauncher.enable = true;
    procs.enable = true;
    pulsemixer.enable = true;
    python.enable = true;
    qpwgraph.enable = true;
    radeontop.enable = true;
    radv.enable = true;
    ripgrep.enable = true;
    rocksmith.enable = true;
    saleae.enable = true;
    samba.enable = true;
    sd.enable = true;
    smartmontools.enable = true;
    sox.enable = true;
    starship.enable = true;
    streamcontroller.enable = true;
    stress-ng.enable = true;
    sysbench.enable = true;
    sysdiag.enable = true;
    sysstat.enable = true;
    tcpdump.enable = true;
    tealdeer.enable = true;
    testdisk.enable = true;
    theme.enable = true;
    tokei.enable = true;
    tree.enable = true;
    usbutils.enable = true;
    virt-manager.enable = true;
    vkbasalt.enable = true;
    vscode.enable = true;
    vulkan-tools.enable = true;
    wget.enable = true;
    wine.enable = true;
    xdg.enable = true;
    xh.enable = true;
    xrizer.enable = true;
    yazi.enable = true;
    yeetmouse.enable = true;
    zellij.enable = true;
    zoxide.enable = true;
    zsh.enable = true;
  };

  # Module sub-settings / tuning (host-specific).
  myModules.home = {
    # Native GUI off: its Chromium/webview can't render in the multi-GPU + NVIDIA VFIO
    # profiles (GBM unsupported → Vulkan fallback → DBus-unresponsive → zombie + wedged
    # singleton lock). The daemon (coolercontrold) still applies all fan profiles; view/
    # configure via the browser web UI at https://localhost:11987 (same interface, renders fine).
    coolercontrol.autostart = true;
    goxlr.denoise.enable = true;
    goxlr.eq.enable = true;
    goxlr.toggle.enable = true;
    konsole.gpuAcceleration = true;
    lmstudio.channel = "beta";
    lmstudio.server.enable = true;
    lmstudio.server.autostart = true;
    atuin.sync = false; # Local only — enable when self-hosted atuin-server is set up
    mullvad.autostart = true; # GUI starts in tray on login; does NOT auto-connect
    syncthing = {
      enable = false; # disabled: stale DBs + unfinished cross-CLI symlink arch; ssh+rsync instead
      folders = {
        documents = {
          path = "/home/user/Documents";
          # Standard patterns live in the syncthing module — single source.
          ignorePatterns = config.myModules.home.syncthing.defaultIgnorePatterns.documents;
        };
        ai-context = {
          path = "/home/user/.ai-context";
          ignorePatterns = config.myModules.home.syncthing.defaultIgnorePatterns.ai-context;
        };
      };
    };
    neovim.ui.enable = true;
    neovim.lsp.enable = true;
    neovim.lsp.nix = true; # (default)
    neovim.lsp.bash = true; # (default)
    neovim.lsp.c = true; # Embedded firmware (ARM + ESP32)
    neovim.lsp.typescript = true; # Mobile/Expo React Native
    neovim.lsp.dotnet = true; # Decryptor projects
    neovim.lsp.powershell = true; # Portable build tooling
    neovim.lsp.python = true; # Personal scripting (gpucycler, scripts) + tooling
    neovim.lsp.markdown = true; # (default)
    neovim.lsp.lua = true; # (default)
    neovim.lsp.yaml = true; # (default)
    neovim.lsp.json = true; # (default)
    neovim.lsp.spell = true; # cspell en/de/es
    plasma.discoverNotifier = true; # (default) — keep update-watch tray icon
    plasma.appearance.enable = true;
    plasma.kwin.enable = true;
    plasma.panels.enable = true;
    # Taskbar pins (host-specific flatpak apps — kept out of the shared panels
    # module so it never references apps this host may not install).
    plasma.panels.height = 44;
    plasma.panels.screen = 0;
    plasma.panels.pinnedLaunchers = [
      "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/io.gitlab.librewolf-community.desktop"
      "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/io.github.ungoogled_software.ungoogled_chromium.desktop"
      "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/eu.betterbird.Betterbird.desktop"
      "applications:systemsettings.desktop"
      "preferred://filemanager"
    ];
    plasma.power.enable = true;
    plasma.shortcuts.enable = true;
    rocksmith.goxlr.lineInRouting = true;
    cod-clients.cblauncher.enable = true;
    cod-clients.cblauncher.gameDirs = [ "/home/user/Games/CoD" ];
    cod-clients.cblauncher.extraWinetricks = [
      "dotnet472"
      "msasn1"
      "win10"
      "grabfullscreen=y"
    ];
    cod-clients.steamNative.enable = true;
    cod-clients.protonPath = "${pkgs.proton-ge.v11.steamcompattool}";
    cod-clients.protonPaths = {
      s1 = "${pkgs.proton-ge.v10.steamcompattool}";
      iw6 = "${pkgs.proton-ge.v10.steamcompattool}";
    };
    cod-clients.alterware.s1 = {
      enable = true;
      gameDir = "/home/user/Games/CoD/aw_game_files";
    };
    cod-clients.alterware.iw6 = {
      enable = true;
      gameDir = "/home/user/Games/CoD/ghosts_game_files";
    };
  };

  # Gaming options (migrated from NixOS)
  myModules.home = {
    radv.experimental = "transfer_queue"; # Mesa 26 dedicated SDMA transfer-only queue — async DMA uploads (perf win, no efficiency cost; nggc/gpl are already default-on, so "" lost nothing)
    radv.vulkanDeviceName = "AMD Radeon RX 9070 XT";
    wine.variant = "staging";
    wine.bottles.enable = true;
    vkbasalt = {
      toggleKey = "Pause";
      effects = "cas:Vibrance:LiftGammaGain";
      casSharpness = "0.5";
      extraConfig = ''
        # Vibrance
        Vibrance = 0.35
        # LiftGammaGain
        LiftGammaGainLift = 1.0,1.0,1.0,1.02
        LiftGammaGainGamma = 1.0,1.0,1.0,0.98
        LiftGammaGainGain = 1.0,1.0,1.0,1.03
      '';
    };
  };

  # GoXLR audio options (migrated from NixOS)
  myModules.home = {
    goxlr.eq = {
      clearStreamProperties = true;
      channels = {
        system.eq = config.myModules.home.goxlr.eq.presets.dt990pro;
        game.eq = config.myModules.home.goxlr.eq.presets.dt990pro;
        chat.eq = config.myModules.home.goxlr.eq.presets.dt990pro;
        music.eq = config.myModules.home.goxlr.eq.presets.dt990pro;
        sample.eq = config.myModules.home.goxlr.eq.presets.dt990pro;
      };
    };
    goxlr.denoise = {
      attenuationLimit = 12;
      minThreshold = -10.0;
      maxErbThreshold = 10.0;
      maxDfThreshold = 8.0;
    };
    goxlr.toggle = {
      activeProfile = "Yellow Default";
      activeMicProfile = "Mic NeatKingBee";
      sleepProfile = "Sleep";
      sleepMicProfile = "Sleep";
    };
  };

  # Arkenfox
  myModules.home = {
    arkenfox.targetDir = "${config.home.homeDirectory}/.var/app/io.gitlab.librewolf-community/.librewolf/ulnbwvmb.default";
  };

  # CoreCycler
  myModules.home = {
    corecycler.unfreeBackends = true;
  };

  # vscodium: FHS package + marketplace extensions (host-specific)
  programs.vscodium = {
    package = pkgs.vscodium.fhs;
    profiles.default = {
      userSettings = {
        "extensions.autoCheckUpdates" = false;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
        "http.systemCertificatesNode" = true;
        "vscode-serial-monitor.customBaudRates" = [
          460800
          921600
        ];
        "editor.formatOnSave" = true;
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "C_Cpp.intelliSenseEngine" = "disabled";
        "clangd.path" = "clangd";
        "terminal.integrated.gpuAcceleration" = "off";
        "terminal.integrated.unicodeVersion" = "11";
      };

      extensions = [
        # Official AI Extensions
        #pkgs.vscode-marketplace.anthropic.claude-code
        #pkgs.vscode-marketplace.google.gemini-cli-vscode-ide-companion
        #pkgs.vscode-marketplace.google.geminicodeassist

        # Official Nix Support
        pkgs.vscode-marketplace.bbenoist.nix
        pkgs.vscode-marketplace.jnoortheen.nix-ide

        # PowerShell
        pkgs.vscode-marketplace.ms-vscode.powershell

        # C/C++ Development (clangd + cpptools)
        pkgs.vscode-marketplace.llvm-vs-code-extensions.vscode-clangd
        pkgs.vscode-marketplace.ms-vscode.cpptools

        # PlatformIO (embedded development)
        pkgs.vscode-marketplace.platformio.platformio-ide

        # Excalidraw (whiteboard diagrams)
        pkgs.vscode-marketplace.pomdtr.excalidraw-editor

        # Expo & React Development
        pkgs.vscode-marketplace.expo.vscode-expo-tools
        pkgs.vscode-marketplace.dsznajder.es7-react-js-snippets
        pkgs.vscode-marketplace.esbenp.prettier-vscode
        pkgs.vscode-marketplace.dbaeumer.vscode-eslint
        pkgs.vscode-marketplace.formulahendry.auto-close-tag
        pkgs.vscode-marketplace.formulahendry.auto-rename-tag

        # Icon Theme
        pkgs.open-vsx.laurenttreguier.vscode-simple-icons

        # Serial Monitor
        pkgs.vscode-marketplace.ms-vscode.vscode-serial-monitor
      ];
    };
  };

  # Logitech G502 — disable acceleration (handled by yeetmouse)
  # Three device IDs: yeetmouse virtual (407f), wired (c08d), wireless receiver (c539)
  programs.plasma.input.mice = [
    {
      name = "Logitech G502";
      vendorId = "046d";
      productId = "407f"; # yeetmouse virtual device
      acceleration = 0;
      accelerationProfile = "none";
    }
    {
      name = "Logitech G502 LIGHTSPEED Wireless Gaming Mouse";
      vendorId = "046d";
      productId = "c08d"; # wired USB
      acceleration = 0;
      accelerationProfile = "none";
    }
    {
      name = "Logitech G502 LIGHTSPEED Wireless Gaming Mouse";
      vendorId = "046d";
      productId = "c539"; # wireless receiver
      acceleration = 0;
      accelerationProfile = "none";
    }
  ];

  # Desktop — no auto-lock or lock-on-resume
  programs.plasma.kscreenlocker = {
    autoLock = false;
    lockOnResume = false;
  };

  # btop layout — preset 0 (launch): cpu/mem/net/proc. Press 'p' → preset 1: all GPUs.
  # btop auto-shows only GPUs present on the host, so the box set tracks the boot profile:
  #   default     → gpu0 iGPU + gpu1 RX 9070 XT + gpu2 GTX 1660S  (all three)
  #   vfio-dynamic → nvidia is disabled (iGPU + 9070 XT show); whichever dGPU a
  #                  running VM grabbed (libvirt vfio-pci) drops out while it runs
  # NVIDIA visibility needs btop's cudaSupport (set in home/modules/btop). Index↔GPU order
  # is btop's probe order — verify at runtime; the gpu2 token is a no-op when only 2 exist.
  programs.btop.settings = {
    selected_preset = 0;
    shown_boxes = "cpu mem net proc";
    presets = lib.concatStringsSep " " [
      "cpu:0:default,mem:0:default,net:0:default,proc:0:default"
      "cpu:0:default,gpu0:0:default,gpu1:0:default,gpu2:0:default,mem:0:default,proc:0:default"
    ];
    show_cpu_watts = lib.mkDefault true;
  };

  # Flatpak packages (host-specific)
  services.flatpak.packages = [
    "com.calibre_ebook.calibre"
    "com.github.jeromerobert.pdfarranger"
    "com.obsproject.Studio"
    "com.spotify.Client"
    "com.rtosta.zapzap"
    "de.bund.ausweisapp.ausweisapp2"
    "eu.betterbird.Betterbird"
    "io.github.milkshiift.GoofCord"
    "io.github.flattool.Ignition"
    "io.github.giantpinkrobots.flatsweep"
    "io.github.ungoogled_software.ungoogled_chromium"
    "io.gitlab.librewolf-community"
    "org.ardour.Ardour"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
    "org.gnome.meld"
    "org.kicad.KiCad"
    "org.libreoffice.LibreOffice"
    "org.remmina.Remmina"
    "org.signal.Signal"
    "org.videolan.VLC"
  ];

  # App-specific overrides
  services.flatpak.overrides = {
    "org.signal.Signal".Environment = {
      SIGNAL_PASSWORD_STORE = "kwallet6";
    };
    "com.rtosta.zapzap".Context = {
      filesystems = [ "xdg-download" ];
    };
  };

  # SSH Client Configuration (for remote deployment to MacBook)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Client aliases from the private registry (names, users, the remote
    # LUKS-unlock endpoint) merge with the literal entries below.
    settings =
      lib.listToAttrs (map (e: lib.nameValuePair e.host e.settings) site.network.pins.sshClientSettings)
      // {
        "*" = {
          KexAlgorithms = "mlkem768x25519-sha256,curve25519-sha256,curve25519-sha256@libssh.org";
        };
        "macbook" = {
          HostName = "macbook-pro-9-2.local"; # mDNS — avahi resolves .local hostnames
          User = "root";
          IdentityFile = "~/.ssh/id_ed25519";
          StrictHostKeyChecking = "accept-new"; # Auto-accept on first connect, verify after
        };
        "macbook-user" = {
          HostName = "macbook-pro-9-2.local";
          User = "user";
          IdentityFile = "~/.ssh/id_ed25519";
          StrictHostKeyChecking = "accept-new";
        };
        # Pixel VM — via ADB bridge to AVF VM
        "pixel-9-pro" = {
          User = "droid";
          ProxyCommand =
            let
              serial = site.hosts.pixel-9-pro.adb.serial;
            in
            "${pkgs.writeShellScript "adb-proxy-pixel" ''
              set -uo pipefail
              ADB=${pkgs.android-tools}/bin/adb
              NC=${pkgs.libressl.nc}/bin/nc
              TIMEOUT=${pkgs.coreutils}/bin/timeout
              SERIAL="${serial}"
              PORT=22220

              state=$($TIMEOUT 5 $ADB -s "$SERIAL" get-state 2>&1) || true
              case "$state" in
                *device*)
                  if $ADB -s "$SERIAL" forward tcp:$PORT tcp:2222 2>/dev/null; then
                    exec $NC -w 10 localhost $PORT
                  fi
                  echo "pixel-proxy: adb forward failed" >&2; exit 1 ;;
                *unauthorized*) echo "pixel-proxy: phone unauthorized — unlock and tap Allow" >&2; exit 1 ;;
                *offline*)      echo "pixel-proxy: phone offline — reconnect USB" >&2; exit 1 ;;
              esac
              echo "pixel-proxy: no ADB device (check USB + Terminal app)" >&2
              exit 1
            ''}";
          StrictHostKeyChecking = "accept-new";
        };
      };
  };
}
