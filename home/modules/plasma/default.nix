# Plasma Manager Configuration
# Declarative KDE Plasma settings via Home Manager
# Split into dendritic sub-modules for maintainability
{
  config,
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:

let
  # Late-tile — KWin helper that retiles windows whose WM_CLASS arrives late
  # (common with Electron/Flatpak apps like Spotify, Obsidian, etc.)
  # When a window's class changes after creation, it re-assigns the window to
  # an empty tile so Fluid Tile can manage it.
  late-tile = pkgs.stdenvNoCC.mkDerivation {
    pname = "kwin-script-late-tile";
    version = "1.0.0";

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/kwin/scripts/late-tile/contents/code

      cat > $out/share/kwin/scripts/late-tile/metadata.json << 'METADATA'
      {
        "KPlugin": {
          "Id": "late-tile",
          "Name": "Late Tile",
          "Description": "Retiles windows whose WM_CLASS arrives after window creation",
          "Version": "1.0.0",
          "License": "GPL-3.0",
          "Category": "Window Management"
        },
        "X-Plasma-API": "javascript",
        "X-Plasma-MainScript": "code/main.mjs"
      }
      METADATA

      cat > $out/share/kwin/scripts/late-tile/contents/code/main.mjs << 'SCRIPT'
      // late-tile: retile windows whose resourceClass changes after creation.
      // Electron/Flatpak apps often set WM_CLASS late, causing tiling scripts
      // to miss them on windowAdded. This script watches for class changes and
      // assigns the window to an available tile.

      const pending = new Set();

      function findEmptyTile(screen, desktop) {
        const root = workspace.tilingForScreen(screen)?.rootTile;
        if (!root) return null;

        const queue = [root];
        while (queue.length > 0) {
          const tile = queue.shift();
          if (tile.tiles.length > 0) {
            for (const child of tile.tiles) queue.push(child);
          } else if (tile.windows.length === 0) {
            return tile;
          }
        }
        return null;
      }

      function tryTile(window) {
        // Skip windows that are already tiled, blocked, or not normal
        if (window.tile !== null || !window.normalWindow ||
            !window.resizeable || !window.maximizable || window.transient) {
          return;
        }

        const tile = findEmptyTile(window.output, workspace.currentDesktop);
        if (tile) {
          tile.manage(window);
        }
      }

      function onWindowAdded(window) {
        // If the window has no class yet, watch for it to appear
        if (window.resourceClass === "" || window.resourceClass === "unknown") {
          pending.add(window);
          window.windowClassChanged.connect(() => {
            if (!pending.has(window)) return;
            pending.delete(window);
            // Small delay to let the window settle
            Qt.callLater(() => tryTile(window));
          });
        }
      }

      function onWindowRemoved(window) {
        pending.delete(window);
      }

      workspace.windowAdded.connect(onWindowAdded);
      workspace.windowRemoved.connect(onWindowRemoved);

      // Check existing windows on script load
      for (const window of workspace.stackingOrder) {
        onWindowAdded(window);
      }
      SCRIPT

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "KWin script to retile windows with late WM_CLASS";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
    };
  };

  # Fluid Tile — KWin auto-tiling script
  # To update: change rev to new tag, set sha256 = "" and rebuild — Nix prints the correct hash.
  # Tags: https://codeberg.org/Serroda/fluid-tile/tags
  fluid-tile = pkgs.stdenvNoCC.mkDerivation {
    pname = "kwin-script-fluid-tile";
    version = "7.0-RC4";

    src = pkgs.fetchgit {
      url = "https://codeberg.org/Serroda/fluid-tile.git";
      rev = "v7.0-RC4";
      sha256 = "sha256-wJLFLPITW5Z9unu+TOJQditeVWXkR2R4+I1yepeVYS8=";
    };

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/kwin/scripts/fluid-tile
      cp -r contents $out/share/kwin/scripts/fluid-tile/
      cp metadata.json $out/share/kwin/scripts/fluid-tile/
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Auto tiling KWin script for KDE Plasma 6.4+";
      homepage = "https://codeberg.org/Serroda/fluid-tile";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
    };
  };
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./appearance.nix
    ./apps.nix
    ./input.nix
    ./kwin.nix
    ./panels.nix
    ./power.nix
    ./shortcuts.nix
  ];

  # ============================================================================
  # User Packages
  # ============================================================================
  home.packages = with pkgs; [
    # Core KDE utilities
    kdePackages.kcalc # Calculator
    kdePackages.kcharselect # Special character selector
    kdePackages.kclock # Clock app
    kdePackages.kcolorchooser # Color picker
    # File management & disk tools
    kdePackages.filelight # Disk usage analyzer
    kdePackages.isoimagewriter # Write ISO to USB
    kdePackages.partitionmanager # Partition manager
    kdePackages.plasma-disks # Disk health monitoring
    kdePackages.kio-extras # Additional KIO protocols

    # System & Connectivity
    kdePackages.kdeconnect-kde # Phone integration
    kdePackages.ksystemlog # System log viewer
    kdePackages.baloo # File indexer

    # Wayland utilities
    wayland-utils
    wl-clipboard # Clipboard

    # KDE debugging & diagnostics
    kdePackages.kdebugsettings # Configure Qt/KDE debug logging categories
    kdePackages.plasma-sdk # Plasma development & debugging tools (plasmoidviewer, etc.)

    # KWin Scripts
    fluid-tile # Auto-tiling for KDE Plasma
    late-tile # Retile windows with late WM_CLASS (Electron/Flatpak)

  ];

  # ============================================================================
  # PROGRAMS.PLASMA - Enable
  # ============================================================================
  programs.plasma.enable = true;

  # ============================================================================
  # Notes on Settings NOT Manageable via plasma-manager:
  # - kwinoutputconfig.json (monitor VRR, HDR, color depth) - hardware-specific
  # - Per-screen wallpapers
  # ============================================================================
}
