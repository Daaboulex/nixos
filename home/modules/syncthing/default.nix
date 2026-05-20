# syncthing — Syncthing folder sync configuration with declarative folders and peer devices.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.syncthing;

  # ────────────────────────────────────────────────────────────────────
  # Standard ignore-pattern sets — single source of truth.
  #
  # Exposed via the `defaultIgnorePatterns` option so hosts reference
  # these by name instead of duplicating long pattern lists per-host.
  # A new pattern goes here once; a new host gets the same exclusions
  # by referencing `config.myModules.home.syncthing.defaultIgnorePatterns.<name>`.
  #
  # Cross-repo SSOT note: the per-CLI dotdirs (`(?d)**/.claude/`,
  # `.gemini/`, `.codex/`, `.pi/`) duplicate `toolLocalDirs()` in
  # ~/.ai-context/modules/hooks/lib/tool-detect.js. The ai-context
  # `scripts/test-hooks.mjs` behavioral assertion 'nix syncthing
  # ignore-patterns match toolLocalDirs() (cross-repo SSOT)' greps
  # this file at every 9-rung ladder run and fails if a CLI added to
  # ai-context's tool registry is not reflected here.
  # ────────────────────────────────────────────────────────────────────
  standardIgnorePatterns = {
    documents = [
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
      # Cross-repo SSOT: matches toolLocalDirs() in ai-context.
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

    ai-context = [
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
in
{
  options.myModules.home.syncthing = {
    enable = lib.mkEnableOption "Syncthing folder sync configuration";

    folders = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path to sync";
            };
            ignorePatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Patterns to exclude from sync (Syncthing .stignore format)";
            };
            versioning = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable staggered file versioning (30-day retention)";
            };
          };
        }
      );
      default = { };
      description = "Folders to sync via Syncthing";
    };

    devices = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "ryzen-9950x3d" = "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH";
      };
      description = "Map of device names to Syncthing device IDs";
    };

    peerDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Device names (from devices) to share all folders with";
    };

    # Standard pattern sets exposed as read-only option values. Hosts use
    # `config.myModules.home.syncthing.defaultIgnorePatterns.<name>` to
    # reference them. Source-of-truth: the `standardIgnorePatterns`
    # let-binding at the top of this module file.
    defaultIgnorePatterns = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = standardIgnorePatterns;
      readOnly = true;
      description = ''
        Standard ignore-pattern sets for common synced trees (documents,
        ai-context). Hosts reference these by name instead of duplicating
        long pattern lists across host configs. The full lists live at
        the top of this module file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Write .stignore files for each folder
    home.file = lib.mapAttrs' (
      _name: folder:
      lib.nameValuePair "${lib.removePrefix "/home/${config.home.username}/" folder.path}/.stignore" {
        text = lib.concatStringsSep "\n" (
          [
            "// Syncthing ignore patterns — managed by Home Manager"
            "// Do not edit manually"
          ]
          ++ folder.ignorePatterns
          ++ [ "" ]
        );
      }
    ) (lib.filterAttrs (_: f: f.ignorePatterns != [ ]) cfg.folders);

    home.packages = [
      pkgs.syncthing
      pkgs.syncthingtray # System tray + Dolphin/Plasma integration
    ];

    # Autostart tray icon with KDE
    xdg.configFile."autostart/syncthingtray.desktop".text = ''
      [Desktop Entry]
      Name=Syncthing Tray
      Exec=syncthingtray
      Type=Application
      X-KDE-autostart-phase=2
      X-KDE-StartupNotify=false
    '';
  };
}
