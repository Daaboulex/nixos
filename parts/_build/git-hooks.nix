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
      mkExhaustivenessCheck = import ./checks/mkExhaustivenessCheck.nix { inherit pkgs; };
      check-placement-bin = import ./checks/check-placement.nix { inherit pkgs; };
      check-scrub-tokens-bin = import ./checks/check-scrub-tokens.nix { inherit pkgs; };
    in
    {
      # Hooks run alphabetically by attr name. The current order is intentional:
      #   1. auto-format    — format first, so later hooks see clean code
      #   2. hm-exhaustiveness — fast grep check
      #   3. nix-eval-check — slow eval, runs on already-formatted code
      # Do not rename hooks without considering execution order.
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
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # HM exhaustiveness — every host default.nix lists every HM module.
        hm-exhaustiveness = {
          enable = true;
          name = "hm-exhaustiveness";
          entry = toString (
            (mkExhaustivenessCheck {
              kind = "HM";
              name = "hm-exhaustiveness";
              hostGlob = "home/hosts/*/default.nix";
              moduleListCmd = "find home/modules -mindepth 1 -maxdepth 1 -type d -not -name '_*' -exec basename {} \\; | sort";
              # Match both forms:
              #   inline      foo.enable = true;
              #   block-nested foo = { enable = true; … };
              expectedPattern = "^[[:space:]]+%s(\\.enable|[[:space:]]*=[[:space:]]*\\{)";
              fixHint = "Host configs must list ALL HM modules. Add missing toggles alphabetically.";
              stagedFilter = "'home/'";
            })
            + "/bin/hm-exhaustiveness"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # NixOS exhaustiveness — every host flake-module.nix references every
        # parts/**/*.nix module. Catches "added a module, forgot to wire it up".
        nixos-exhaustiveness = {
          enable = true;
          name = "nixos-exhaustiveness";
          entry = toString (
            (mkExhaustivenessCheck {
              kind = "NixOS";
              name = "nixos-exhaustiveness";
              hostGlob = "parts/hosts/*/flake-module.nix";
              # Every parts/**/*.nix module declares 'flake.modules.nixos.<name> = mod;'.
              # Extract the <name>, excluding _build and host files themselves.
              moduleListCmd = "grep -rhE '^\\s*flake\\.modules\\.nixos\\.[a-zA-Z0-9_-]+' parts --include='*.nix' --exclude-dir=_build --exclude-dir=hosts | sed -E 's/^[[:space:]]*flake\\.modules\\.nixos\\.([a-zA-Z0-9_-]+).*/\\1/' | sort -u";
              expectedPattern = "inputs\\.self\\.modules\\.nixos\\.%s";
              fixHint = "Host flake-module.nix files must reference every NixOS module under parts/. Add the missing inputs.self.modules.nixos.<name> import alphabetically.";
              stagedFilter = "'parts/'";
            })
            + "/bin/nixos-exhaustiveness"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # ─── Style enforcement hooks (STYLE §8.3) ─────────────────────────

        # Forbid `with lib;` anywhere in tracked .nix files.
        check-no-with-lib = {
          enable = true;
          name = "check-no-with-lib";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-no-with-lib";
              runtimeInputs = with pkgs; [
                git
                gnugrep
              ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR -- '*.nix')
                [ -z "$staged" ] && exit 0
                failed=0
                for f in $staged; do
                  if [ -f "$f" ] && grep -nE '^\s*with\s+lib\s*;' "$f" >/dev/null; then
                    echo "VIOLATION ($f): 'with lib;' is forbidden (STYLE §1.3)."
                    grep -nE '^\s*with\s+lib\s*;' "$f" | head -3
                    failed=1
                  fi
                done
                exit "$failed"
              '';
            })
            + "/bin/check-no-with-lib"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # ROADMAP.md is a planning artifact; docs/ is reserved for
        # published project documentation (STYLE.md, BUILD.md,
        # installation.md, etc.). Planning lives outside docs/; exact
        # location is operator-configurable via
        # `git config nix.roadmapDestination <path>`. This hook fails
        # loudly if anyone tries to (re-)introduce `docs/ROADMAP.md`.
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

        # Every `lib.mkForce` must have a `# Why:` comment on the same line
        # or within the previous 2 lines.
        check-mkforce-comment = {
          enable = true;
          name = "check-mkforce-comment";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-mkforce-comment";
              runtimeInputs = with pkgs; [
                git
                gawk
              ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR -- '*.nix')
                [ -z "$staged" ] && exit 0
                failed=0
                for f in $staged; do
                  [ -f "$f" ] || continue
                  # Host files (parts/hosts/*/, home/hosts/*/) are the final
                  # authority — their mkForce usages don't need rationale.
                  case "$f" in
                    parts/hosts/*|home/hosts/*) continue ;;
                  esac
                  # "Why:" covers every mkForce that follows it before the
                  # next non-comment, non-blank, non-mkForce line. This lets
                  # a multi-line `# Why: …` block explain an adjacent mkForce
                  # even when unrelated file-level content (a docstring) sits
                  # many lines above the block.
                  missing=$(awk '
                    /^[[:space:]]*#/ {
                      if ($0 ~ /# *Why:/) pending_why = 1
                      next
                    }
                    /^[[:space:]]*$/ { next }
                    /lib\.mkForce/ {
                      if ($0 ~ /# *Why:/) { pending_why = 0; next }
                      if (pending_why) next
                      printf "  %d: %s\n", NR, $0
                      next
                    }
                    { pending_why = 0 }
                  ' "$f")
                  if [ -n "$missing" ]; then
                    echo "VIOLATION ($f): lib.mkForce without adjacent '# Why:' comment (STYLE §2.3):"
                    echo "$missing"
                    failed=1
                  fi
                done
                exit "$failed"
              '';
            })
            + "/bin/check-mkforce-comment"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Every assertion's message must start with "myModules." (STYLE §3.2).
        check-assertion-format = {
          enable = true;
          name = "check-assertion-format";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-assertion-format";
              runtimeInputs = with pkgs; [
                git
                gawk
              ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR -- '*.nix')
                [ -z "$staged" ] && exit 0
                failed=0
                for f in $staged; do
                  [ -f "$f" ] || continue
                  # Pair each "assertion = ... ;" block with its next "message = ...".
                  bad=$(awk '
                    /^[[:space:]]+assertion[[:space:]]*=/ { want_msg=1; line_num=NR }
                    want_msg && /^[[:space:]]+message[[:space:]]*=/ {
                      want_msg=0
                      # If message is a "..." or '''..''' string literal, capture
                      # contents on the same and next few lines
                      buf = $0
                      for (i=1; i<=4 && getline nl > 0; i++) buf = buf " " nl
                      # Does buf contain the canonical prefix within the quotes?
                      if (buf !~ /myModules\./) {
                        printf "  %d: assertion message does not start with myModules.*\n", line_num
                      }
                    }
                  ' "$f")
                  if [ -n "$bad" ]; then
                    echo "VIOLATION ($f): assertion message format (STYLE §3.2):"
                    echo "$bad"
                    failed=1
                  fi
                done
                exit "$failed"
              '';
            })
            + "/bin/check-assertion-format"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Every non-helper module SHOULD have a top docstring comment.
        # ADVISORY (exit 0): pre-existing tree has ~60 modules that need
        # backfill. Hook logs warnings so new modules get flagged in review,
        # but doesn't block commits. Flip to `failed` below → exit 1 after
        # Stage 9 docstring backfill lands.
        check-module-docstring = {
          enable = true;
          name = "check-module-docstring";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-module-docstring";
              runtimeInputs = with pkgs; [
                git
                coreutils
                gnugrep
              ];
              text = ''
                staged=$(git diff --cached --name-only --diff-filter=ACMR -- \
                  'home/modules/*.nix' 'home/modules/**/*.nix' \
                  'parts/*.nix' 'parts/**/*.nix')
                [ -z "$staged" ] && exit 0
                warned=0
                for f in $staged; do
                  [ -f "$f" ] || continue
                  case "$f" in
                    # Excluded paths:
                    # - home/lib/* + parts/_build/* — shared helpers / build utilities
                    # - parts/sensors/drivers/* — callPackage derivations (Shape C), not modules
                    # - parts/hosts/*/hardware-configuration.nix — nixos-generate-config output
                    home/lib/*|parts/_build/*) continue ;;
                    parts/sensors/drivers/*) continue ;;
                    parts/hosts/*/hardware-configuration.nix) continue ;;
                  esac
                  if grep -q 'mkSimplePackage' "$f"; then continue; fi
                  lines=$(wc -l < "$f")
                  [ "$lines" -lt 10 ] && continue
                  first=$(grep -m1 -vE '^\s*$' "$f" || true)
                  if [ -z "$first" ] || [ "''${first###}" = "$first" ]; then
                    echo "VIOLATION ($f): missing module docstring (STYLE §4.1)."
                    warned=1
                  fi
                done
                # Enforcing as of T2 — backlog zeroed by T3 on 2026-04-16.
                # If you intentionally want a module without a docstring,
                # either shorten it under 10 lines or use mkSimplePackage.
                [ "$warned" -ne 0 ] && {
                  echo ""
                  echo "Prepend '# <name> — <one-line purpose>.' to the file(s) above."
                  exit 1
                }
                exit 0
              '';
            })
            + "/bin/check-module-docstring"
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # Refuse commits when the local branch is behind its upstream.
        # Prevents the divergent-histories foot-gun when two hosts commit
        # without pulling first, which then requires manual rebase to unify.
        # Fetches with a short timeout so offline work still passes.
        # Also checks any additional git directories named via
        # `git config --get-all nix.extraSubmodulePaths` (defaults to
        # empty; operators seed with
        # `git config --add nix.extraSubmodulePaths <path>` once per
        check-secrets-leak = {
          enable = true;
          name = "check-secrets-leak";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "check-secrets-leak";
              runtimeInputs = [ pkgs.git ];
              text = ''
                # Block staging any file in secrets/ except secrets.nix.
                # Also block .age, .key, .pem, and private key files.
                failed=0
                while IFS= read -r f; do
                  case "$f" in
                    secrets/secrets.nix) ;; # allowed — public keys only
                    secrets/*)
                      echo "BLOCKED: $f — secrets/ files must not be committed (except secrets.nix)"
                      failed=1 ;;
                    *.age|*.key|*.pem|*_rsa|*_ed25519|*_ecdsa)
                      echo "BLOCKED: $f — cryptographic material"
                      failed=1 ;;
                  esac
                done < <(git diff --cached --name-only --diff-filter=ACM)
                exit $failed
              '';
            })
            + "/bin/check-secrets-leak"
          );
          language = "system";
          stages = [ "pre-commit" ];
          pass_filenames = false;
          always_run = true;
        };

        # local checkout). SKIP=check-behind-remote bypasses for emergencies.
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
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # File path ⟺ option scope path (STYLE.md §13a). Hook grabs staged
        # files itself; test derivation invokes the binary with positional
        # args to exercise both paths.
        check-placement = {
          enable = true;
          name = "check-placement";
          entry = toString (check-placement-bin + "/bin/check-placement");
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

        # Content scrub gate (STYLE.md §8.5) — blocks personal/work tokens
        # in staged diffs, sourced from canonical catalog at
        # $HOME/.ai-context/scripts/scrub-config.json. Exits 0 if config
        # absent (fresh-clone resilience).
        check-scrub-tokens = {
          enable = true;
          name = "check-scrub-tokens";
          entry = toString (check-scrub-tokens-bin + "/bin/check-scrub-tokens");
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };

        # update-docs hook removed — generated docs are now build artifacts
        # via `nix build .#docs` (parts/_build/docs.nix). No auto-commit
        # of OPTIONS.md, options.json, or templates.
      };

      devShells.default = config.pre-commit.devShell;
    };
}
