{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Home Manager State Version (moved from dissolved base module)
  home.stateVersion = "26.05";

  # HM Module Toggles — exhaustive, alphabetical
  myModules.home = {
    android.enable = true;
    antigravity.enable = false;
    anydesk.enable = true;
    archive.enable = true;
    arkenfox.enable = true;
    azahar.enable = false;
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
    coolercontrol.enable = false;
    corecycler.enable = false;
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
    easyeffects.enable = true;
    eden.enable = false;
    elisa.enable = false;
    ethtool.enable = true;
    eza.enable = true;
    fastfetch.enable = true;
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
    goxlr.enable = false;
    goxlr.denoise.enable = false;
    goxlr.eq.enable = false;
    goxlr.toggle.enable = false;
    gparted.enable = true;
    gpg.enable = true;
    gtk.enable = true;
    heroic.enable = false;
    htop.enable = false;
    hwinfo.enable = true;
    hyperfine.enable = true;
    ifuse.enable = true;
    inxi.enable = true;
    iodiag.enable = true; # I/O pressure snapshot — diagnose A400 hangs
    iommu.enable = false;
    iotop.enable = true; # Per-process disk I/O monitor
    iw.enable = true;
    jaeger.enable = false;
    jq.enable = true;
    kate.enable = true;
    kdotool.enable = true;
    kiro.enable = false;
    konsole.enable = true;
    konsole.gpuAcceleration = true;
    lact.enable = false;
    lazygit.enable = true;
    libimobiledevice.enable = true;
    llmfit.enable = false;
    lm-sensors.enable = true;
    lmstudio.enable = false;
    looking-glass.enable = false;
    lsfg-vk.enable = false;
    lshw.enable = true;
    lsof.enable = true;
    macbook.enable = true; # Apple keyboard remap, Mac-like Spaces, dock tweaks
    man-pages.enable = true;
    mangohud.enable = false;
    mangojuice.enable = false; # MangoHud GUI — gaming, not needed on laptop
    memtest-vulkan.enable = false;
    minicom.enable = true;
    models.enable = false;
    moonlight.enable = false;
    atuin.enable = true;
    atuin.sync = false; # Disabled — self-host atuin-server before re-enabling
    mullvad.enable = true;
    mullvad.autostart = true; # GUI starts in tray on login; does NOT auto-connect
    syncthing = {
      enable = true;
      folders = {
        documents = {
          path = "/home/user/Documents";
          ignorePatterns = [
            # ── NEGATIONS FIRST (first-match-wins) ──
            # AI skill dirs named "build"/"packages": NOT build artifacts.
            # Without this, `**/build/` silently blocks sync of
            # <work-monorepo>/.claude/skills/build/ (legitimate skill content).
            "!**/.claude/skills/*/"
            "!**/.gemini/skills/*/"

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

            # ── Git internals — FULL exclusion ──
            # No trailing slash: matches both .git/ dirs (normal repos) AND
            # .git files (submodule/worktree pointers like .ai-context/.git).
            # Both hosts maintain history via push/pull to GitHub remotes.
            ".git"

            # ── Syncthing own artifacts ──
            ".stversions/"
            "**/*.sync-conflict-*"

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
        claude = {
          path = "/home/user/.claude";
          ignorePatterns = [
            # ── Regenerable caches — (?d) safe ──
            "(?d)image-cache/"
            "(?d)statsig/"
            "(?d)telemetry/"
            "(?d)plans/" # Claude Code per-session plan files
            "(?d)paste-cache/" # ephemeral paste/share refs
            "(?d)debug/" # transient debug logs
            "(?d).skill-log-*.jsonl" # per-session skill invocation logs
            ".reflect-proposals.md"
            # ── Security: NO (?d) — OAuth tokens are per-machine auth ──
            # ── Security: per-machine OAuth tokens ──
            ".credentials.json"
            ".credentials.*"
            # ── Plugin state: absolute paths differ per machine ──
            "plugins/installed_plugins.json"
            "plugins/installed_plugins.json.bak-*"
            "plugins/install-counts-cache.json"
            # ── Per-machine runtime state (NOT session data — those sync) ──
            ".dream-session-count"
            ".dream-lock"
            ".dream-last"
            ".reflect-last"
            ".auto-push-last"
            ".catchup-done"
            "active-sessions.jsonl"
            "self-improvements-pending*.jsonl"
            # ── Ephemeral agent task outputs ──
            "(?d)tasks/"
            # ── Syncthing own artifacts ──
            "(?d).stversions/"
            # ── Git transient files (auto-push handles sync via remotes) ──
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
          ];
        };
        gemini = {
          path = "/home/user/.gemini";
          ignorePatterns = [
            # ── Security: per-machine auth ──
            "oauth_creds.json"
            "google_accounts.json"
            "installation_id"
            # ── Per-machine runtime state ──
            ".dream-session-count"
            ".dream-lock"
            ".dream-last"
            ".reflect-last"
            ".catchup-done"
            "state.json"
            # ── Regenerable caches ──
            "(?d)tmp/skill-*"
            "(?d)tmp/*.tmp"
            "(?d)tmp/bin/"
            "(?d)cache/"
            # ── Syncthing own artifacts ──
            "(?d).stversions/"
            # ── Git transient files ──
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
          ];
        };
        codex = {
          path = "/home/user/.codex";
          ignorePatterns = [
            # ── Security: per-machine auth ──
            "auth.json"
            "installation_id"
            # ── Binary databases (will conflict, machine-rebuilt) ──
            "(?d)logs_2.sqlite*"
            "(?d)state_5.sqlite*"
            "(?d)models_cache.json"
            # ── Regenerable caches ──
            "(?d)cache/"
            "(?d)log/"
            "(?d).tmp/"
            "(?d)tmp/"
            ".personality_migration"
            # ── Syncthing own artifacts ──
            "(?d).stversions/"
            # ── Git transient files ──
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
    neovim.lsp.c = true; # Occasional C editing
    neovim.lsp.typescript = false; # No frontend work on the MacBook
    neovim.lsp.dotnet = false; # No .NET here
    neovim.lsp.powershell = false; # No PS work here
    neovim.lsp.spell = true; # cspell still useful for docs
    nil.enable = true;
    nix-output-monitor.enable = true;
    nix-prefetch-git.enable = true;
    nix-tree.enable = true;
    ns-usbloader.enable = false;
    node.enable = true;
    nvd.enable = true;
    occt.enable = false;
    okular.enable = true;
    opencode.enable = false;
    openviking.enable = false;
    pastel.enable = true;
    pciutils.enable = true;
    piper.enable = false;
    pkg-config.enable = true;
    plasma.enable = true;
    plasma.gpuBackend = "opengl"; # Mature, stable path for HD 4000
    plasma.discoverNotifier = false; # silence cupsd Create-Printer-Subscriptions bad-request spam
    plasma.appearance.enable = true;
    plasma.kwin.enable = true;
    plasma.panels.enable = true;
    plasma.power.enable = true;
    plasma.shortcuts.enable = true;
    powershell.enable = true;
    powertop.enable = true;
    prismlauncher.enable = false;
    protonplus.enable = false;
    pulsemixer.enable = true;
    python.enable = true;
    qpwgraph.enable = true;
    radeontop.enable = false; # No AMD GPU
    radv.enable = false;
    ripgrep.enable = true;
    rocksmith.enable = false;
    ryubing.enable = false;
    saleae.enable = false;
    samba.enable = true;
    sd.enable = true;
    sherlock.enable = true;
    smartmontools.enable = true;
    starship.enable = true;
    streamcontroller.enable = false;
    stress-ng.enable = false;
    sysbench.enable = false;
    sysdiag.enable = true;
    sysstat.enable = true; # sar/iostat/pidstat — I/O evidence collection
    tcpdump.enable = true;
    tealdeer.enable = true;
    testdisk.enable = true;
    theme.enable = true;
    tidalcycles.enable = true;
    tokei.enable = true;
    tree.enable = true;
    usbutils.enable = true;
    virt-manager.enable = false;
    vkbasalt.enable = false;
    vscode.enable = true;
    vulkan-tools.enable = true;
    wget.enable = true;
    wine.enable = true;
    xdg.enable = true;
    xh.enable = true;
    yazi.enable = true;
    yeetmouse.enable = false;
    zellij.enable = true;
    zoxide.enable = true;
    zsh.enable = true;
  };

  # Per-host overrides
  myModules.home = {
    arkenfox.targetDir = "${config.home.homeDirectory}/.var/app/io.gitlab.librewolf-community/.librewolf/default";
    wine.variant = "staging";
    wine.bottles.enable = false;
  };

  # Dock: hide the virtual desktop pager widget (dock real estate is tight on 1280×800)
  myModules.home = {
    plasma.panels.showPager = false;
  };

  # Virtual desktops — 4 horizontal spaces with wrap-around, so the built-in
  # KWin 4-finger touchpad swipe (Plasma 6 Wayland default) can cycle through
  # them like macOS Spaces. RollOverDesktops makes the last→first wrap.
  programs.plasma.kwin.virtualDesktops = {
    number = 4;
    rows = 1;
  };
  programs.plasma.configFile."kwinrc"."Windows"."RollOverDesktops" = true;

  # Keyboard (physical Ctrl is broken — remap Cmd/⌘ to Ctrl via the Meta path):
  #   caps:super              → Caps Lock emits Super
  #   ctrl:swap_lwin_lctl     → LWin ↔ LCtrl. With hidApple.swapOptCmd = false,
  #                             physical Cmd emits LWin, so this makes ⌘ act as Ctrl.
  #                             Option stays as Alt; (broken) physical Ctrl becomes Meta.
  programs.plasma.input.keyboard.options = [
    "caps:super"
    "ctrl:swap_lwin_lctl"
  ];

  # ── HD4000 Performance Tuning ──
  # Instant animations — HD4000 can't render smooth animations, so skip them entirely
  programs.plasma.configFile."kdeglobals"."KDE"."AnimationDurationFactor" = 0;
  # Disable Baloo file indexing — uses 25% CPU (1 full core) during indexing on 2C/4T
  programs.plasma.configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  # KWin blur left ON per user preference. Base plasma module enables it via
  # mkDefault; keeping that default here. If HD 4000 shader cost becomes
  # visible on scroll/window-move, flip back to false.
  # Night Light — keep enabled, other optimizations compensate for the minimal GPU cost
  # programs.plasma.configFile."kwinrc"."NightColor"."Active" = lib.mkForce false;
  # Disable activity tracking — reduces background CPU
  programs.plasma.configFile."kactivitymanagerdrc"."Plugins"."org.kde.ActivityManager.ResourceScoringEnabled" =
    false;

  # Per-host git credentials via myModules.home.git.settings
  myModules.home = {
    git.settings.settings.user = {
      name = "Daaboulex";
      email = "39669593+Daaboulex@users.noreply.github.com";
    };
  };

  # Laptop power management — suspend on lid close, battery profile
  programs.plasma.powerdevil = {
    AC = {
      autoSuspend.action = "nothing";
      dimDisplay = {
        enable = true;
        idleTimeout = 300; # Dim after 5 min on AC
      };
      turnOffDisplay.idleTimeout = 600; # Turn off after 10 min
      powerProfile = "balanced";
    };
    battery = {
      autoSuspend = {
        action = "sleep";
        idleTimeout = 600; # Suspend after 10 min on battery
      };
      dimDisplay = {
        enable = true;
        idleTimeout = 120; # Dim after 2 min on battery
      };
      turnOffDisplay.idleTimeout = 300; # Turn off after 5 min
      powerProfile = "powerSaving";
    };
    lowBattery = {
      autoSuspend = {
        action = "sleep";
        idleTimeout = 300; # Suspend after 5 min on low battery
      };
      dimDisplay = {
        enable = true;
        idleTimeout = 30; # Dim after 30 sec
      };
      turnOffDisplay.idleTimeout = 60; # Turn off after 1 min
      powerProfile = "powerSaving";
    };
  };

  # Laptop — keep screen locker enabled (module defaults: autoLock=true, lockOnResume=true)

  # btop layout — single Intel HD4000 GPU
  programs.btop.settings = {
    shown_boxes = lib.mkForce "cpu gpu0 mem proc";
    presets = lib.mkForce "cpu:0:default,gpu0:0:default,mem:0:default,proc:0:default";
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
    "io.gitlab.adhami3310.Impression" # USB image writer
    "io.gitlab.librewolf-community"
    "md.obsidian.Obsidian"
    "org.ardour.Ardour"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
    "org.gnome.meld"
    "org.kde.kdenlive"
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
}
