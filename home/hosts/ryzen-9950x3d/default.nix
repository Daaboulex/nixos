{
  config,
  lib,
  pkgs,
  site,
  ...
}:

let
  flatpakApp =
    id:
    "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/${id}.desktop";
in

{
  imports = [
    ./goxlr
    ./coolercontrol
    ./streamcontroller
  ];

  # Home Manager State Version (moved from dissolved base module)
  home.stateVersion = "26.05";

  # HM Module Toggles — exhaustive, alphabetical
  myModules.home = {
    android.enable = true;
    antigravity.enable = false;
    anydesk.enable = true;
    archive.enable = true;
    arkenfox.enable = true;
    azahar.enable = true;
    bat.enable = true;
    bluez-tools.enable = true;
    brightnessctl.enable = true;
    btop.enable = true;
    c-cpp.enable = true;
    chafa.enable = true;
    cifs-utils.enable = true;
    claude-code.enable = true;
    codex-cli.enable = true;
    cmake.enable = true;
    comma.enable = true;
    crush.enable = false;
    coolercontrol.enable = true;
    coolercontrol.autostart = true;
    corecycler.enable = true;
    csvlens.enable = true;
    curl.enable = true;
    delta.enable = true;
    devenv.enable = true;
    dig.enable = true;
    direnv.enable = true;
    displays.enable = true;
    dmidecode.enable = true;
    duf.enable = true;
    durdraw.enable = true;
    dust.enable = true;
    easyeffects.enable = false;
    eden.enable = true;
    elisa.enable = false;
    ethtool.enable = true;
    eza.enable = true;
    fastfetch.enable = true;
    fd.enable = true;
    ffmpeg.enable = true;
    flatpak.enable = true;
    fzf.enable = true;
    gamescope.enable = false;
    gcc.enable = true;
    gdb.enable = true;
    gemini-cli.enable = true;
    git.enable = true;
    glow.enable = true;
    gnumake.enable = true;
    goxlr.enable = true;
    goxlr.denoise.enable = true;
    goxlr.eq.enable = true;
    goxlr.toggle.enable = true;
    gparted.enable = true;
    gpg.enable = true;
    gtk.enable = true;
    heroic.enable = true;
    htop.enable = false;
    hwinfo.enable = true;
    hyperfine.enable = true;
    ifuse.enable = true;
    inxi.enable = true;
    iodiag.enable = true; # I/O pressure snapshot — available on both hosts
    iommu.enable = true;
    iotop.enable = true; # Per-process disk I/O monitor
    iw.enable = true;
    jaeger.enable = false;
    jq.enable = true;
    kate.enable = true;
    kdotool.enable = true;
    kiro.enable = false;
    kiro.cli = false;
    konsole.enable = true;
    konsole.gpuAcceleration = true;
    lact.enable = true;
    lazygit.enable = true;
    libimobiledevice.enable = true;
    llmfit.enable = true;
    lm-sensors.enable = true;
    lmstudio.enable = true;
    lmstudio.channel = "beta";
    lmstudio.server.enable = true;
    lmstudio.server.autostart = true;
    looking-glass.enable = true;
    lsfg-vk.enable = true;
    lshw.enable = true;
    lsof.enable = true;
    macbook.enable = false; # Desktop, not a MacBook
    man-pages.enable = true;
    mangohud.enable = true;
    mangojuice.enable = true;
    memtest-vulkan.enable = true;
    minicom.enable = true;
    models.enable = true;
    moonlight.enable = true;
    atuin.enable = true;
    atuin.sync = false; # Local only — enable when self-hosted atuin-server is set up
    mullvad.enable = true;
    mullvad.autostart = true; # GUI starts in tray on login; does NOT auto-connect
    syncthing = {
      enable = true;
      folders = {
        documents = {
          path = "/home/user/Documents";
          ignorePatterns = [
            # ── NEGATIONS FIRST (first-match-wins) ──
            # (skill negations removed — skills unified to project-state/ which IS synced)

            # ── Regenerable build artifacts — (?d) safe ──
            # (?d) allows Syncthing to delete these when they block dir removal.
            # Safe: all recreated by their respective build tools.
            "(?d)result"
            "(?d)result-*"
            "(?d).direnv/"
            "(?d)node_modules/"
            "(?d)__pycache__/"
            "(?d)*.pyc"
            # ESP32 / PlatformIO
            "(?d)**/.pio/"
            # Java / Android
            "(?d)**/.gradle/"
            "(?d)**/.cxx/"
            # Generic build output (negation above protects AI skill dirs)
            "(?d)**/build/"
            # .NET build artifacts
            "(?d)**/obj/"
            # Python
            "(?d)**/.pytest_cache/"
            "(?d)**/.venv/"
            # Generic caches (<sub-project>/<hw-variant>/.cache, etc.)
            "(?d)**/.cache/"

            # ── Machine-specific generated files ──
            # nix-direnv: contains local nix store paths, diverges per host
            "(?d).pre-commit-config.yaml"
            # Visual Studio: per-machine workspace state
            "(?d)**/.vs/"
            "**/*.user"
            # Obsidian: workspace.json is window positions, per-machine
            "**/.obsidian/workspace.json"
            "**/.obsidian/workspace-mobile.json"

            # ── Git internals — targeted transient exclusion ──
            # Sync .git/ so history travels with files (no "forgot to push").
            # Only exclude transient lock/state files from in-progress ops.
            # Safe: loose objects + packfiles are content-addressed (immutable).
            # Single-user = no concurrent git operations across hosts.
            "(?d).git/**/*.lock"
            "(?d).git/gc.log"
            "(?d).git/gc.pid"
            "(?d).git/MERGE_HEAD"
            "(?d).git/MERGE_MSG"
            "(?d).git/MERGE_MODE"
            "(?d).git/CHERRY_PICK_HEAD"
            "(?d).git/REBASE_HEAD"
            "(?d).git/REVERT_HEAD"
            "(?d).git/BISECT_HEAD"
            "(?d).git/AUTO_MERGE"
            "(?d).git/rebase-merge/"
            "(?d).git/rebase-apply/"
            "(?d).git/sequencer/"
            "(?d).git/objects/pack/tmp_*"

            # ── Syncthing own artifacts ──
            ".stversions/"
            "**/*.sync-conflict-*"

            # ── Per-machine AI tool dirs in projects ──
            # Created by Claude Code / session-start hooks per-machine.
            # Contain symlinks (not portable), settings.local.json, caches.
            # (?d) allows Syncthing to delete when remote removes them.
            "(?d)**/.claude/"
            "(?d)**/.gemini/"
            "(?d)**/.codex/"
            "(?d)**/.pi/"

            # ── Per-machine AI runtime state (NOT session data) ──
            "**/active-sessions.jsonl"
            "**/.autosave-stashes.log"
            "**/.nrb-update.lock"

            # ── Claude Code sandbox artifacts (root-anchored) ──
            # Sandbox bind-mounts /dev/null over secrets and creates empty
            # placeholder files at session start. Per-machine.
            "/package.json"
            "/bunfig.toml"
            "/.gitmodules"
            "/.env"
            "/.env.local"
            "/.env.development"
            "/.env.development.local"
            "/.env.production"
            "/.env.production.local"
            "/.env.test"
            "/.env.test.local"
          ];
        };
        ai-context = {
          path = "/home/user/.ai-context";
          ignorePatterns = [
            # ── Git internals — targeted transient exclusion ──
            "(?d).git/**/*.lock"
            "(?d).git/gc.log"
            "(?d).git/gc.pid"
            "(?d).git/MERGE_HEAD"
            "(?d).git/MERGE_MSG"
            "(?d).git/MERGE_MODE"
            "(?d).git/CHERRY_PICK_HEAD"
            "(?d).git/REBASE_HEAD"
            "(?d).git/REVERT_HEAD"
            "(?d).git/BISECT_HEAD"
            "(?d).git/AUTO_MERGE"
            "(?d).git/rebase-merge/"
            "(?d).git/rebase-apply/"
            "(?d).git/sequencer/"
            "(?d).git/objects/pack/tmp_*"
            # ── Syncthing conflict files — must never be committed ──
            "*.sync-conflict-*"
            # ── Per-machine volatile state ──
            "(?d)instances/"
            "(?d)/projects/"
            "(?d)backups/"
            "(?d)cache/"
            # ── High-churn telemetry (per-machine, 27MB+) ──
            "(?d)**/episodic/"
            # ── Handoff session volatiles ──
            "(?d)handoffs/sessions/.current-*"
            "(?d)handoffs/sessions/.debounce-*"
            "(?d)handoffs/sessions/.git-cache-*"
            # ── Nested git repos — have their own remotes ──
            "kachow-mirror/"
            # ── Handoff volatiles ──
            "(?d)handoffs/sessions/*.json"
            "(?d)handoffs/projects/*.json"
            # ── Per-machine runtime state ──
            "(?d)runtime/"
            "**/active-sessions*.jsonl"
            "**/.autosave-recovery.log"
            "(?d).auto-push-last"
            "(?d)telemetry-epoch.json"
            "(?d)*.lock"
            "(?d)**/.frontmatter-cache.json"
            # ── Dream/consolidation state (per-machine) ──
            "(?d).dream-last"
            "(?d).dream-session-count"
            "(?d).dream-lock"
            "(?d).research-last"
            "(?d).research-session-count"
            # ── Archived brainstorm files (~1.8 MB, not needed cross-machine) ──
            "(?d).superpowers/"
            # ── Syncthing own artifacts ──
            "(?d).stversions/"
            # ── Obsidian vault metadata — per-machine, must not sync ──
            ".obsidian/"
          ];
        };
      };
    };
    nano.enable = true;
    neovim.enable = true;
    neovim.ui.enable = true;
    neovim.lsp.enable = true;
    neovim.lsp.nix = true; # (default)
    neovim.lsp.bash = true; # (default)
    neovim.lsp.c = true; # Embedded firmware (ARM + ESP32)
    neovim.lsp.typescript = true; # Mobile/Expo React Native
    neovim.lsp.dotnet = true; # Decryptor projects
    neovim.lsp.powershell = true; # Portable build tooling
    neovim.lsp.markdown = true; # (default)
    neovim.lsp.lua = true; # (default)
    neovim.lsp.yaml = true; # (default)
    neovim.lsp.json = true; # (default)
    neovim.lsp.spell = true; # cspell en/de/es
    nil.enable = true;
    nix-output-monitor.enable = true;
    nix-prefetch-git.enable = true;
    nix-tree.enable = true;
    ns-usbloader.enable = true;
    node.enable = true;
    nvd.enable = true;
    obsidian.enable = true;
    occt.enable = true;
    okular.enable = true;
    opencode.enable = false;
    openviking.enable = false;
    pi.enable = true;
    pastel.enable = true;
    pciutils.enable = true;
    piper.enable = true;
    pkg-config.enable = true;
    plasma.enable = true;
    plasma.discoverNotifier = true; # (default) — keep update-watch tray icon
    plasma.appearance.enable = true;
    plasma.kwin.enable = true;
    plasma.panels.enable = true;
    plasma.power.enable = true;
    plasma.shortcuts.enable = true;
    powershell.enable = true;
    powertop.enable = true;
    prismlauncher.enable = true;
    protonplus.enable = true;
    pulsemixer.enable = true;
    python.enable = true;
    qpwgraph.enable = true;
    radeontop.enable = true;
    radv.enable = true;
    ripgrep.enable = true;
    rocksmith.enable = true;
    rocksmith.goxlr.lineInRouting = true;
    ryubing.enable = true;
    saleae.enable = true;
    samba.enable = true;
    sd.enable = true;
    sherlock.enable = true;
    smartmontools.enable = true;
    starship.enable = true;
    streamcontroller.enable = true;
    stress-ng.enable = true;
    sysbench.enable = true;
    sysdiag.enable = true;
    sysstat.enable = true; # sar/iostat/pidstat — performance evidence
    tcpdump.enable = true;
    tealdeer.enable = true;
    testdisk.enable = true;
    theme.enable = true;
    tidalcycles.enable = true;
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
    yazi.enable = true;
    yeetmouse.enable = true;
    zellij.enable = true;
    zoxide.enable = true;
    zsh.enable = true;
    zsh.gc.devShellDirs = [
      "$HOME/Documents/nix/"
      "$HOME/Documents/fahlke-monorepo/Development-*/"
    ];
    zsh.gc.devShellFlake = "$HOME/Documents/fahlke-monorepo/Portable-Builder";
    zsh.gc.devShellNames = [
      "default"
      "esp32"
      "mobile"
      "dotnet"
      "emulator"
    ];
  };

  # Gaming options (migrated from NixOS)
  myModules.home = {
    radv.perftest = "";
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

  # TidalCycles
  myModules.home = {
    tidalcycles.autostartSuperDirt = false;
  };

  # Per-host git credentials via myModules.home.git.settings
  myModules.home = {
    git.settings.settings.user = {
      name = "Daaboulex";
      email = "39669593+Daaboulex@users.noreply.github.com";
    };
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

  programs.plasma.panels = lib.mkForce [
    {
      location = "bottom";
      height = 44;
      floating = false;
      lengthMode = "fill";
      screen = 0;
      widgets = [
        {
          name = "org.kde.plasma.kickoff";
          config.General.favoritesPortedToKAstats = "true";
        }
        "org.kde.plasma.pager"
        {
          name = "org.kde.plasma.icontasks";
          config.General = {
            launchers = [
              (flatpakApp "io.gitlab.librewolf-community")
              (flatpakApp "io.github.ungoogled_software.ungoogled_chromium")
              (flatpakApp "eu.betterbird.Betterbird")
              "applications:systemsettings.desktop"
              "preferred://filemanager"
            ];
          };
        }
        "org.kde.plasma.marginsseparator"
        {
          name = "org.kde.plasma.systemtray";
          config.General.showVirtualDevices = "true";
        }
        {
          name = "org.kde.plasma.digitalclock";
          config.Appearance = {
            use24hFormat = "2";
            dateFormat = "custom";
            customDateFormat = "dddd, d MMMM yyyy";
            dateDisplayFormat = "BelowTime";
          };
        }
      ];
    }
  ];

  # btop layout — GPUs shown compactly in CPU header (show_gpu_info)
  # gpu0 = Zen 5 iGPU, gpu1 = RX 9070 XT
  programs.btop.settings = {
    selected_preset = lib.mkForce 0;
    # No separate gpu boxes — GPUs in CPU header via show_gpu_info
    shown_boxes = lib.mkForce "cpu mem net proc";
    presets = lib.mkForce (
      lib.concatStringsSep " " [
        "cpu:0:default,mem:0:default,net:0:default,proc:0:default"
        "cpu:0:default,gpu0:0:default,gpu1:0:default,mem:0:default,proc:0:default"
      ]
    );
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
    matchBlocks = {
      "*" = {
        extraOptions = {
          KexAlgorithms = "mlkem768x25519-sha256,curve25519-sha256,curve25519-sha256@libssh.org";
        };
      };
      "macbook" = {
        hostname = "macbook-pro-9-2.local"; # mDNS — avahi resolves .local hostnames
        user = "root";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "accept-new"; # Auto-accept on first connect, verify after
        };
      };
      "macbook-user" = {
        hostname = "macbook-pro-9-2.local";
        user = "user";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
        };
      };
      # Pixel VM — via ADB bridge to AVF VM
      "pixel-9-pro" = {
        user = "droid";
        proxyCommand =
          let
            serial = site.hosts.pixel-9-pro.adb.serial;
          in
          "adb -s ${serial} shell 'nc $(cat /proc/net/arp | awk \"/avf_tap/{print \\$1}\") 2222'";
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
        };
      };
    };
  };
}
