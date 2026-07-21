{
  config,
  pkgs,
  lib,
  site,
  ...
}:

{
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
    comma.enable = true;
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
    easyeffects.enable = true;
    ethtool.enable = true;
    eza.enable = true;
    fastfetch.enable = true;
    fd.enable = true;
    ffmpeg.enable = true;
    flatpak.enable = true;
    free-claude-code.enable = true;
    fzf.enable = true;
    gcc.enable = true;
    gdb.enable = true;
    ghostty.enable = true; # GTK terminal; HD 4000 caps at GL 4.2 — see softwareRendering note below
    git.enable = true;
    glow.enable = true;
    gnumake.enable = true;
    gparted.enable = true;
    gpg.enable = true;
    gtk.enable = true;
    hermes.enable = true;
    hexyl.enable = true;
    hwinfo.enable = true;
    hyperfine.enable = true;
    ifuse.enable = true;
    inxi.enable = true;
    iodiag.enable = true;
    iotop.enable = true;
    iw.enable = true;
    jq.enable = true;
    kate.enable = true;
    kdotool.enable = true;
    konsole.enable = true;
    lazygit.enable = true;
    libimobiledevice.enable = true;
    lm-sensors.enable = true;
    lshw.enable = true;
    lsof.enable = true;
    macbook.enable = true;
    man-pages.enable = true;
    minicom.enable = true;
    moonlight.enable = true; # Remote desktop client (Sunshine peer)
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
    okular.enable = true;
    opencode.enable = true;
    pastel.enable = true;
    pciutils.enable = true;
    pi.enable = true;
    pkg-config.enable = true;
    plasma.enable = true;
    powershell.enable = true;
    powertop.enable = true;
    procs.enable = true;
    pulsemixer.enable = true;
    python.enable = true;
    qpwgraph.enable = true;
    ripgrep.enable = true;
    samba.enable = true;
    sd.enable = true;
    smartmontools.enable = true;
    sox.enable = true;
    starship.enable = true;
    sysdiag.enable = true;
    sysstat.enable = true;
    tcpdump.enable = true;
    tealdeer.enable = true;
    testdisk.enable = true;
    theme.enable = true;
    tokei.enable = true;
    tree.enable = true;
    usbutils.enable = true;
    vscode.enable = true;
    vulkan-tools.enable = true;
    wget.enable = true;
    wine.enable = true;
    xdg.enable = true;
    xh.enable = true;
    yazi.enable = true;
    zellij.enable = true;
    zoxide.enable = true;
    zsh.enable = true;
  };

  # Module sub-settings / tuning (host-specific).
  myModules.home = {
    konsole.gpuAcceleration = true;
    # HD 4000 reports GL 4.2 but Mesa exposes the 4.3 feature set (compute
    # shaders, SSBOs) as extensions, so Ghostty runs GPU-accelerated once Mesa
    # is told to report 4.3. (Verified live: surface inits, no OpenGLOutdated.)
    ghostty.renderer = "gl-override";
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
    neovim.lsp.c = true; # Occasional C editing
    neovim.lsp.typescript = false; # No frontend work on the MacBook
    neovim.lsp.dotnet = false; # No .NET here
    neovim.lsp.powershell = false; # No PS work here
    neovim.lsp.markdown = true; # (default)
    neovim.lsp.lua = true; # (default)
    neovim.lsp.yaml = true; # (default)
    neovim.lsp.json = true; # (default)
    neovim.lsp.spell = true; # cspell still useful for docs
    plasma.gpuBackend = "opengl"; # Mature, stable path for HD 4000
    plasma.discoverNotifier = false; # silence cupsd Create-Printer-Subscriptions bad-request spam
    plasma.appearance.enable = true;
    plasma.kwin.enable = true;
    plasma.panels.enable = true;
    plasma.power.enable = true;
    plasma.shortcuts.enable = true;
  };

  # Per-host overrides
  myModules.home = {
    arkenfox.targetDir = "${config.home.homeDirectory}/.var/app/io.gitlab.librewolf-community/.librewolf/fhtyqcou.default-default"; # LibreWolf active profile (profiles.ini Install default)
    wine.variant = "staging";
    wine.bottles.enable = false;
  };

  # Dock: hide the virtual desktop pager widget (dock real estate is tight on 1280×800)
  myModules.home = {
    plasma.panels.showPager = false;
    # Taskbar pins (host-specific flatpak apps — kept out of the shared panels
    # module so it never references apps this host may not install).
    plasma.panels.pinnedLaunchers = [
      "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/io.gitlab.librewolf-community.desktop"
      "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/io.github.ungoogled_software.ungoogled_chromium.desktop"
      "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/eu.betterbird.Betterbird.desktop"
      "applications:systemsettings.desktop"
      "preferred://filemanager"
    ];
  };

  # Virtual desktops come from macbook.workspaces (enabled via macbook.enable
  # above): 4 horizontal Spaces with wrap-around for the KWin 4-finger swipe.
  # Re-declaring them here would be a second writer for the same kwin keys.

  # Keyboard remap (physical Ctrl is broken -- remap Cmd to Ctrl via the Meta path).
  # Both xkb options are ALREADY supplied by modules, so this host must NOT re-add
  # them: re-adding wrote each twice into kxkbrc and KWin rejected the duplicate
  # ("XKB-595 Unrecognized RMLVO option ... was ignored").
  #   caps:super          -- Caps Lock emits Super          (home/modules/plasma/input.nix)
  #   ctrl:swap_lwin_lctl -- LWin <-> LCtrl; with hidApple.swapOptCmd = false the
  #                          physical Cmd emits LWin, so Cmd acts as Ctrl end-to-end
  #                          (home/modules/macbook/keyboard.nix)

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

  # Laptop power management — suspend on lid close, battery profile
  # AC behaviour comes from plasma/power.nix defaults (enabled above);
  # only the battery profiles are host-specific here.
  programs.plasma.powerdevil = {
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

  # btop layout — single Intel HD4000 GPU (module defaults are mkDefault;
  # plain values override without masking future normal-priority writers)
  programs.btop.settings = {
    shown_boxes = "cpu gpu0 mem proc";
    presets = "cpu:0:default,gpu0:0:default,mem:0:default,proc:0:default";
  };

  # Flatpak packages (host-specific)
  services.flatpak.packages = [
    #"com.calibre_ebook.calibre"
    "com.github.jeromerobert.pdfarranger"
    "com.obsproject.Studio"
    "com.spotify.Client"
    "com.rtosta.zapzap"
    "de.bund.ausweisapp.ausweisapp2"
    "eu.betterbird.Betterbird"
    "io.github.milkshiift.GoofCord"
    #"io.github.flattool.Ignition"
    "io.github.giantpinkrobots.flatsweep"
    "io.github.ungoogled_software.ungoogled_chromium"
    #"io.gitlab.adhami3310.Impression" # USB image writer
    "io.gitlab.librewolf-community"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
    "org.gnome.meld"
    "org.libreoffice.LibreOffice"
    "org.remmina.Remmina"
    "org.signal.Signal"
    "org.videolan.VLC"
  ];

  # SSH client — registry aliases (names, users, the remote LUKS-unlock
  # endpoint; values live in site) merged with pixel-9-pro via ADB bridge to
  # AVF VM. The ProxyCommand auto-discovers the phone via mDNS if no ADB
  # device is connected; works over USB and wireless debugging.
  programs.ssh.enable = true;
  programs.ssh.enableDefaultConfig = false;
  programs.ssh.settings =
    lib.listToAttrs (map (e: lib.nameValuePair e.host e.settings) site.network.pins.sshClientSettings)
    // {
      pixel-9-pro = {
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

            # ADB port forwarding for binary-clean SSH transport.
            # adb shell corrupts binary packets. ADB forward creates a proper TCP
            # socket — same mechanism as "ssh -p 2222 droid@localhost".
            # Port 22220 avoids conflicts with the udev Syncthing forward on 22001
            # and any other listener on 2222.

            setup_forward() {
              if ! $ADB -s "$1" forward tcp:$PORT tcp:2222 2>/dev/null; then
                echo "pixel-proxy: adb forward failed for $1" >&2
                return 1
              fi
              exec $NC -w 10 localhost $PORT
            }

            # 1. Try USB device by serial (5s timeout guards against hung ADB daemon)
            state=$($TIMEOUT 5 $ADB -s "$SERIAL" get-state 2>&1) || true
            case "$state" in
              *device*)     setup_forward "$SERIAL" ;;
              *unauthorized*) echo "pixel-proxy: phone USB connected but unauthorized — unlock phone and tap Allow" >&2; exit 1 ;;
              *offline*)    echo "pixel-proxy: phone USB connected but offline — reconnect USB" >&2; exit 1 ;;
            esac

            # 2. No USB — find wireless ADB via mDNS
            addr=$($TIMEOUT 5 ${pkgs.avahi}/bin/avahi-browse -tpr _adb-tls-connect._tcp 2>/dev/null \
              | ${pkgs.gawk}/bin/awk -F';' '/^=/{print $8":"$9; exit}')
            if [ -n "$addr" ]; then
              if $TIMEOUT 10 $ADB connect "$addr" 2>&1 | grep -q connected; then
                setup_forward "$addr"
              fi
              echo "pixel-proxy: wireless ADB found ($addr) but connect failed" >&2
              exit 1
            fi

            echo "pixel-proxy: no ADB device (USB or wireless). Check: cable, USB debugging ON, Terminal app running." >&2
            exit 1
          ''}";
      };
    };

  # App-specific overrides
  services.flatpak.overrides = {
    "org.signal.Signal".Environment = {
      SIGNAL_PASSWORD_STORE = "kwallet6";
    };
    "com.rtosta.zapzap".Context = {
      filesystems = [ "xdg-download" ];
    };
  };

  # Force H.264 in LibreWolf (Flatpak): HD4000 has no VP9/AV1 hardware decode, so
  # those codecs fall to CPU software decode and saturate the 2 cores. Disabling
  # them at the MSE layer makes YouTube serve H.264 (caps YouTube at 1080p -- fine
  # here; WebRTC is unaffected, this is mediasource-scoped, not media.webm). Written
  # as a REAL file, NOT a home.file symlink: the Flatpak sandbox cannot resolve a
  # symlink into /nix/store, so a symlinked config would be silently ignored.
  # LibreWolf's autoconfig reads this from the .librewolf data root, so it is
  # profile-independent (survives profile renames). lockPref enforces on every start.
  home.activation.librewolfMediaOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    d="$HOME/.var/app/io.gitlab.librewolf-community/.librewolf"
    if [ -d "$d" ]; then
      $DRY_RUN_CMD cp -f ${pkgs.writeText "librewolf.overrides.cfg" ''
        lockPref("media.av1.enabled", false);
        lockPref("media.mediasource.vp9.enabled", false);
        // Cap content processes for the 2-core (Fission still isolates sites within the pool).
        lockPref("dom.ipc.processCount", 3);
      ''} "$d/librewolf.overrides.cfg"
      $DRY_RUN_CMD chmod u+w "$d/librewolf.overrides.cfg"
    else
      echo "librewolf: .librewolf dir absent -- launch LibreWolf once, then re-run nrb"
    fi
  '';
}
