# Shared Syncthing ignorePatterns — referenced from each host's syncthing config.
# Eliminates the 152-line duplication NIX-1 flagged (ryzen-9950x3d +
# macbook-pro-9-2 had byte-identical inline lists). A new host gets the
# same exclusions by importing this file; a new pattern goes here once,
# not per-host.
#
# Audit history: 2026-05-20 — extracted from the inline ignorePatterns lists
# that lived in `home/hosts/<host>/default.nix`. Lists were verified
# byte-identical between hosts before extraction (`diff` against both
# host files returned empty).
{
  # Patterns for /home/user/Documents — the user's working-tree of every
  # active project. Build artifacts, per-machine AI tool dirs, transient
  # git state. Negation/order: Syncthing applies (?d) — allow-delete —
  # to anything that should be deletable when remote removes it.
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

  # Patterns for /home/user/.ai-context — the single global ai-context repo.
  # Different scope than `documents`: this is the tool runtime; volatiles,
  # episodic logs, per-machine handoff state, and runtime caches must NOT
  # sync. The repo itself is a git repo with its own remote — sync the
  # working tree, not the volatile state inside it.
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
}
