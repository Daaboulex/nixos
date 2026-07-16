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
      # Every check binary, imported once (checks/default.nix readDir). A new
      # check joins the gate by adding its name to standardChecks — or a
      # hand-written hook block below when it needs non-standard fields.
      checkBins = import ./checks { inherit pkgs; };
      # The uniform scaffold: pre-commit stage, no filename args. Each check's
      # documentation lives in its own file header.
      standardChecks = [
        "nixos-exhaustiveness"
        "deploy-readiness"
        "check-assertion-format"
        "check-dangling-refs"
        "check-dedup"
        "check-helper-naming"
        "check-mkforce-comment"
        "check-module-class"
        "check-module-docstring"
        "check-no-cross-tree-import"
        "check-no-dated-comments"
        "check-no-foreign-config"
        "check-no-narration-comments"
        "check-no-with-lib"
        "check-pin-behind-checkout"
        "check-placement"
        "check-session-vars"
        "check-specialisation-placement"
      ];
      standardHooks = builtins.listToAttrs (
        map (n: {
          name = n;
          value = {
            enable = true;
            name = n;
            entry = toString (checkBins.${n} + "/bin/${n}");
            stages = [ "pre-commit" ];
            pass_filenames = false;
          };
        }) standardChecks
      );
    in
    {
      # Hooks run alphabetically by attr name; auto-format is named to sort
      # first so every later hook operates on already-formatted code.
      pre-commit.settings.hooks = standardHooks // {
        # commit-msg stage -- subject format + Eval trailer (the ledger gate).
        check-commit-message = {
          enable = true;
          name = "check-commit-message";
          entry = toString (checkBins.check-commit-message + "/bin/check-commit-message");
          stages = [ "commit-msg" ];
          pass_filenames = true;
        };

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
                mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACMR)
                [ "''${#staged[@]}" -eq 0 ] && exit 0

                ${config.treefmt.build.wrapper}/bin/treefmt --no-cache "''${staged[@]}"

                for file in "''${staged[@]}"; do
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
                echo "Evaluating NixOS configurations..."
                configs=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json 2>/dev/null | jq -r '.[]' || true)
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

        # Specialisation eval gate (pre-push). CI evaluates each host's BASE
        # config (ryzen via etc.drvPath, which does NOT force specialisations),
        # so a renamed/undefined option inside a specialisation passes CI and
        # only surfaces at `nrb` switch or boot. This evals every host's
        # specialisation toplevels before a push, closing that gap (the
        # no-cachix half of the audit's ryzen-spec recommendation).
        #
        # Weak-laptop rule: IFD during the eval must never build on a weak
        # client. On the build host it builds locally; elsewhere it forces every
        # build to the remote builder (--max-jobs 0) and SKIPS (never blocks,
        # never builds locally) when that builder is unreachable.
        nix-spec-eval = {
          enable = true;
          name = "nix-spec-eval";
          entry = toString (
            (pkgs.writeShellApplication {
              name = "nix-spec-eval";
              runtimeInputs = with pkgs; [
                nix
                jq
                openssh
                coreutils
              ];
              text = ''
                builder="ryzen-9950x3d"
                self="$(cat /proc/sys/kernel/hostname 2>/dev/null || echo unknown)"

                jobs=""
                if [ "$self" != "$builder" ]; then
                  if timeout 6 ssh -o BatchMode=yes -o ConnectTimeout=5 "remotebuild@''${builder}.local" true 2>/dev/null; then
                    jobs="--max-jobs 0" # force every IFD build to the remote builder
                  else
                    echo "nix-spec-eval: builder ''${builder} unreachable -- skipping (refusing a heavy local build on $self)."
                    exit 0
                  fi
                fi

                configs="$(nix eval .#nixosConfigurations --apply builtins.attrNames --json 2>/dev/null | jq -r '.[]' || true)"
                if [ -z "$configs" ]; then
                  echo "nix-spec-eval: could not enumerate nixosConfigurations (flake eval failed)."
                  exit 1
                fi

                fail=0
                while IFS= read -r cfg; do
                  [ -z "$cfg" ] && continue
                  specs="$(nix eval ".#nixosConfigurations.''${cfg}.config.specialisation" --apply builtins.attrNames --json 2>/dev/null | jq -r '.[]' 2>/dev/null || true)"
                  [ -z "$specs" ] && continue
                  while IFS= read -r spec; do
                    [ -z "$spec" ] && continue
                    attr=".#nixosConfigurations.''${cfg}.config.specialisation.''${spec}.configuration.system.build.toplevel.drvPath"
                    printf "  %s / %s ... " "$cfg" "$spec"
                    # shellcheck disable=SC2086
                    if nix eval $jobs --raw "$attr" >/dev/null 2>&1; then
                      echo "ok"
                    else
                      echo "FAILED"
                      echo "    nix eval '$attr' --show-trace"
                      fail=1
                    fi
                  done <<< "$specs"
                done <<< "$configs"

                if [ "$fail" -ne 0 ]; then
                  echo ""
                  echo "A specialisation failed to evaluate (renamed/undefined option, dangling ref) --"
                  echo "invisible to CI's base-host eval. To bypass: SKIP=nix-spec-eval git push ..."
                  exit 1
                fi
              '';
            })
            + "/bin/nix-spec-eval"
          );
          stages = [ "pre-push" ];
          pass_filenames = false;
        };

        # ─── Style enforcement hooks ──────────────────────────────────────

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

        # Nothing secret belongs in this public repo — all secret material lives
        # in the private `site` registry. Configured in checks/check-secrets-leak.nix
        # (shared with the flake check, which runs --all over the tree).
        check-secrets-leak = {
          enable = true;
          name = "check-secrets-leak";
          entry = toString (checkBins."check-secrets-leak" + "/bin/check-secrets-leak");
          language = "system";
          stages = [ "pre-commit" ];
          pass_filenames = false;
          always_run = true;
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
                mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACMR)
                blocked=""
                for f in "''${staged[@]}"; do
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
