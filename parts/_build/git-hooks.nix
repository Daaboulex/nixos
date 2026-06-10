{ inputs, ... }:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      nixos-exhaustiveness-bin = import ./checks/nixos-exhaustiveness.nix { inherit pkgs; };
      check-placement-bin = import ./checks/check-placement.nix { inherit pkgs; };
      check-dangling-refs-bin = import ./checks/check-dangling-refs.nix { inherit pkgs; };
      check-no-foreign-config-bin = import ./checks/check-no-foreign-config.nix { inherit pkgs; };
      check-dedup-bin = import ./checks/check-dedup.nix { inherit pkgs; };
      check-specialisation-placement-bin = import ./checks/check-specialisation-placement.nix {
        inherit pkgs;
      };
      check-no-narration-comments-bin = import ./checks/check-no-narration-comments.nix { inherit pkgs; };
      check-helper-naming-bin = import ./checks/check-helper-naming.nix { inherit pkgs; };
      check-no-with-lib-bin = import ./checks/check-no-with-lib.nix { inherit pkgs; };
      check-no-dated-comments-bin = import ./checks/check-no-dated-comments.nix { inherit pkgs; };
      check-mkforce-comment-bin = import ./checks/check-mkforce-comment.nix { inherit pkgs; };
      check-assertion-format-bin = import ./checks/check-assertion-format.nix { inherit pkgs; };
      check-module-docstring-bin = import ./checks/check-module-docstring.nix { inherit pkgs; };
      check-secrets-leak-bin = import ./checks/check-secrets-leak.nix { inherit pkgs; };
      check-no-cross-tree-import-bin = import ./checks/check-no-cross-tree-import.nix { inherit pkgs; };
    in
    {
      # Hooks run alphabetically by attr name; auto-format is named to sort
      # first so every later hook operates on already-formatted code.
      pre-commit.settings.hooks = {
        # Disable auto-wired treefmt (replaced by auto-format below)
        treefmt.enable = false;

        # Auto-format staged files and re-stage them (zero-friction formatting).
        auto-format = {
          enable = true;
          name = "auto-format";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "auto-format";
              runtimeInputs = with pkgs; [
                git
                coreutils
              ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR)
                [ -z "$staged" ] && exit 0

                # shellcheck disable=SC2086
                ${config.treefmt.build.wrapper}/bin/treefmt --no-cache $staged

                for file in $staged; do
                  if [ -f "$file" ]; then
                    git add "$file"
                  fi
                done
              '';
            })
            + "/bin/auto-format"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Lightweight eval check — catches broken configs before commit.
        nix-eval-check = {
          enable = true;
          name = "nix-eval-check";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "nix-eval-check";
              runtimeInputs = with pkgs; [
                git
                nix
                jq
              ];
              text = ''
                staged=$(git diff --cached --name-only -- 'parts/' 'home/' 'flake.nix')
                [ -z "$staged" ] && exit 0

                echo "Evaluating NixOS configurations..."
                configs=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json 2>/dev/null | jq -r '.[]')
                if [ -z "$configs" ]; then
                  echo "ERROR: Could not enumerate nixosConfigurations (flake evaluation failed)."
                  echo "To skip this check: SKIP=nix-eval-check git commit ..."
                  exit 1
                fi

                # Shallow eval: force module-system merge without deriving
                # every package (system.build.toplevel is a full derivation
                # tree, ~20 min cold). networking.hostName forces option
                # resolution but stops far short of build computation.
                for cfg in $configs; do
                  printf "  Checking %s... " "$cfg"
                  if nix eval ".#nixosConfigurations.$cfg.config.networking.hostName" > /dev/null 2>&1; then
                    echo "ok"
                  else
                    echo "FAILED"
                    echo ""
                    echo "ERROR: NixOS configuration '$cfg' failed to evaluate."
                    echo "Run: nix eval '.#nixosConfigurations.$cfg.config.networking.hostName' --show-trace"
                    echo ""
                    echo "To skip this check: SKIP=nix-eval-check git commit ..."
                    exit 1
                  fi
                done
                echo "All configurations evaluate successfully."
              '';
            })
            + "/bin/nix-eval-check"
          );
          # pre-push, not pre-commit: 4 host evals are the dominant commit-
          # latency cost; run them before push (CI/garnix is the real gate).
          stages = [ "pre-push" ];
          pass_filenames = false;
        };

        # NixOS exhaustiveness — every host flake-module.nix references every
        # parts/**/*.nix module. Catches "added a module, forgot to wire it up".
        # Configured in checks/nixos-exhaustiveness.nix (shared with the flake
        # check, which runs it with --all).
        nixos-exhaustiveness = {
          enable = true;
          name = "nixos-exhaustiveness";
          entry = toString (nixos-exhaustiveness-bin + "/bin/nixos-exhaustiveness");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # ─── Style enforcement hooks ──────────────────────────────────────

        # Forbid `with lib;` anywhere in tracked .nix files. Configured in
        # checks/check-no-with-lib.nix (shared with the flake check, which runs --all).
        check-no-with-lib = {
          enable = true;
          name = "check-no-with-lib";
          entry = toString (check-no-with-lib-bin + "/bin/check-no-with-lib");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # docs/ is for published documentation; planning/roadmap artifacts
        # belong outside it. Destination is operator-configurable via
        # `git config nix.roadmapDestination <path>`. This hook fails loudly
        # if anyone tries to (re-)introduce `docs/ROADMAP.md`.
        check-no-roadmap-in-docs = {
          enable = true;
          name = "check-no-roadmap-in-docs";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-no-roadmap-in-docs";
              runtimeInputs = with pkgs; [
                git
                gnugrep
              ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR)
                [ -z "$staged" ] && exit 0
                # Match docs/ROADMAP.md, docs/roadmap.md, docs/Roadmap.md
                violations=$(echo "$staged" | grep -iE '^docs/roadmap\.md$' || true)
                if [ -n "$violations" ]; then
                  dest=$(git config --get nix.roadmapDestination || true)
                  echo "VIOLATION: ROADMAP does not belong in docs/ (reserved for project documentation)."
                  if [ -n "$dest" ]; then
                    echo "Move it: mv docs/ROADMAP.md $dest"
                  else
                    echo "Pick a destination outside docs/ and move the file. To suppress this hint next time:"
                    echo "  git config nix.roadmapDestination <path-outside-docs>"
                  fi
                  echo "Files staged in docs/:"
                  echo "$violations"
                  exit 1
                fi
                exit 0
              '';
            })
            + "/bin/check-no-roadmap-in-docs"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Comment standard: no dated change-logs / session narration in comments
        # (git carries the history). Configured in checks/check-no-dated-comments.nix
        # (shared with the flake check, which runs --all).
        check-no-dated-comments = {
          enable = true;
          name = "check-no-dated-comments";
          entry = toString (check-no-dated-comments-bin + "/bin/check-no-dated-comments");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Change-narration / AI-session-narration in comments (the prose form
        # of the dated-comment ban). Configured in
        # checks/check-no-narration-comments.nix (shared with the flake check).
        check-no-narration-comments = {
          enable = true;
          name = "check-no-narration-comments";
          entry = toString (check-no-narration-comments-bin + "/bin/check-no-narration-comments");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Every `lib.mkForce` must have an adjacent `# Why:` rationale. Configured
        # in checks/check-mkforce-comment.nix (shared with the flake check, --all).
        check-mkforce-comment = {
          enable = true;
          name = "check-mkforce-comment";
          entry = toString (check-mkforce-comment-bin + "/bin/check-mkforce-comment");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Every assertion's message must start with "myModules.<path>:". Configured
        # in checks/check-assertion-format.nix (shared with the flake check, --all).
        check-assertion-format = {
          enable = true;
          name = "check-assertion-format";
          entry = toString (check-assertion-format-bin + "/bin/check-assertion-format");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Every module >10 lines must start with a one-line docstring. Configured
        # in checks/check-module-docstring.nix (shared with the flake check, --all).
        check-module-docstring = {
          enable = true;
          name = "check-module-docstring";
          entry = toString (check-module-docstring-bin + "/bin/check-module-docstring");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Nothing secret belongs in this public repo — all secret material lives
        # in the private `site` registry. Configured in checks/check-secrets-leak.nix
        # (shared with the flake check, which runs --all over the tree).
        check-secrets-leak = {
          enable = true;
          name = "check-secrets-leak";
          entry = toString (check-secrets-leak-bin + "/bin/check-secrets-leak");
          language = "system";
          stages = [ "pre-commit" ];
          pass_filenames = false;
          always_run = true;
        };

        # No relative `../…` import crossing the parts/ ↔ home/ tree boundary
        # (use the flake registry / source instead). Configured in
        # checks/check-no-cross-tree-import.nix (shared with the flake check).
        check-no-cross-tree-import = {
          enable = true;
          name = "check-no-cross-tree-import";
          entry = toString (check-no-cross-tree-import-bin + "/bin/check-no-cross-tree-import");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Refuse commits when the local branch is behind its upstream —
        # prevents the divergent-histories foot-gun when two hosts commit
        # without pulling first. Short fetch timeout so offline work passes.
        # Also checks dirs named via `git config --get-all
        # nix.extraSubmodulePaths`. SKIP=check-behind-remote bypasses.
        check-behind-remote = {
          enable = true;
          name = "check-behind-remote";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-behind-remote";
              runtimeInputs = with pkgs; [
                git
                coreutils
              ];
              text = ''
                staged=$(git diff --cached --name-only)
                [ -z "$staged" ] && exit 0

                failed=0
                # Short fetch timeout keeps offline commits fast.
                check_repo() {
                  local label="$1" repo_dir="$2"
                  pushd "$repo_dir" > /dev/null || return 0
                  if ! timeout 5 git fetch --quiet origin 2>/dev/null; then
                    echo "  $label: fetch failed (offline?) — skipping."
                    popd > /dev/null || true
                    return 0
                  fi
                  local upstream
                  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
                  if [ -z "$upstream" ]; then
                    popd > /dev/null || true
                    return 0
                  fi
                  local behind
                  behind=$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
                  if [ "$behind" -gt 0 ]; then
                    echo "ERROR: $label is $behind commit(s) behind $upstream."
                    echo "       Committing now will diverge history and force a later rebase."
                    echo "       Fix: (cd $repo_dir && git pull --rebase origin main)"
                    failed=1
                  fi
                  popd > /dev/null || true
                }

                check_repo "main repo" "."
                while IFS= read -r extra; do
                  [ -z "$extra" ] && continue
                  if [ -d "$extra" ] && [ -e "$extra/.git" ]; then
                    check_repo "$extra submodule" "$extra"
                  fi
                done < <(git config --get-all nix.extraSubmodulePaths 2>/dev/null || true)

                if [ "$failed" -ne 0 ]; then
                  echo ""
                  echo "To bypass for this commit: SKIP=check-behind-remote git commit ..."
                  exit 1
                fi
                exit 0
              '';
            })
            + "/bin/check-behind-remote"
          );
          # pre-push, not pre-commit: a network fetch + "behind upstream" is a
          # push concern, not a per-commit one.
          stages = [ "pre-push" ];
          pass_filenames = false;
        };

        # Specialisations live in specialisations/<name>.nix — a host
        # default.nix may only contain the mkSpecialisations wiring call.
        check-specialisation-placement = {
          enable = true;
          name = "check-specialisation-placement";
          entry = toString (check-specialisation-placement-bin + "/bin/check-specialisation-placement");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # A domain-level parts/<domain>/*.nix is a module or a `_`-prefixed
        # private helper — nothing else. Configured in checks/check-helper-naming.nix.
        check-helper-naming = {
          enable = true;
          name = "check-helper-naming";
          entry = toString (check-helper-naming-bin + "/bin/check-helper-naming");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # File path ⟺ option scope path. Hook grabs staged
        # files itself; test derivation invokes the binary with positional
        # args to exercise both paths.
        check-placement = {
          enable = true;
          name = "check-placement";
          entry = toString (check-placement-bin + "/bin/check-placement");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Unguarded cross-module reference gate (AUDIT.md §19) — a module naming
        # another enable-gated module's binary/.desktop without a `.enable` guard.
        check-dangling-refs = {
          enable = true;
          name = "check-dangling-refs";
          entry = toString (check-dangling-refs-bin + "/bin/check-dangling-refs");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Dendritic-invariant gate (AUDIT.md §19) — a module assigning config into
        # another module's myModules.* namespace (home/modules + parts).
        check-no-foreign-config = {
          enable = true;
          name = "check-no-foreign-config";
          entry = toString (check-no-foreign-config-bin + "/bin/check-no-foreign-config");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Copy-paste backstop to the structural single-source discipline: flags
        # module-level near-duplicate LOGIC blocks (>=50 aligned tokens) to extract
        # into a shared helper. Hosts/fixtures exempt; the granular manifest is
        # suppressed by construction; `# dedup-ok` suppresses a reviewed near-dup.
        check-dedup = {
          enable = true;
          name = "check-dedup";
          entry = toString (check-dedup-bin + "/bin/check-dedup");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Block AI context files from being committed. .ai-context is a
        # symlink to ~/.ai-context/project-state/nix/ — never tracked.
        check-no-ai-files = {
          enable = true;
          name = "check-no-ai-files";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-no-ai-files";
              runtimeInputs = [ pkgs.git ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR)
                blocked=""
                for f in $staged; do
                  case "$f" in
                    .ai-context/*) blocked="$blocked $f" ;;
                    AGENTS.md|CLAUDE.md|GEMINI.md|DEBT.md) blocked="$blocked $f" ;;
                    .claude/*|.gemini/*|.codex/*|.planning/*) blocked="$blocked $f" ;;
                    .crush/*|.opencode/*|.pi/*) blocked="$blocked $f" ;;
                  esac
                done
                if [[ -n "$blocked" ]]; then
                  echo "BLOCKED: AI context files must not be committed:"
                  for f in $blocked; do echo "  $f"; done
                  echo ""
                  echo "These are symlinks/dirs managed by AI tools — never tracked in git."
                  echo "Run: git rm --cached <file> to untrack."
                  exit 1
                fi
              '';
            })
            + "/bin/check-no-ai-files"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Secret scanning — blocks committing passwords, API keys, tokens, and
        # private-key material. gitleaks with its maintained default ruleset +
        # this repo's `.gitleaks.toml` allowlist. Defined explicitly (this
        # git-hooks.nix version ships no built-in gitleaks entry). `protect
        # --staged` scans the staged diff. Replaces the bespoke check-scrub-tokens
        # (which depended on an absent ~/.ai-context catalog).
        gitleaks = {
          enable = true;
          name = "gitleaks";
          entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --redact --no-banner --config .gitleaks.toml";
          language = "system";
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # No docs-generation hook — option docs live in each option's
        # `description` (browse via `nix flake show` / nixos-option).
      };

      devShells.default = config.pre-commit.devShell;
    };
}
