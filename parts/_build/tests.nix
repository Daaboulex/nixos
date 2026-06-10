# NixOS VM integration tests for myModules
# Run: nix build .#checks.x86_64-linux.<test-name>
# Run all: nix flake check (includes these alongside treefmt/git-hooks checks)
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      check-placement-bin = import ../_build/checks/check-placement.nix { inherit pkgs; };
      check-dangling-refs-bin = import ../_build/checks/check-dangling-refs.nix { inherit pkgs; };
      check-no-foreign-config-bin = import ../_build/checks/check-no-foreign-config.nix { inherit pkgs; };
      check-dedup-bin = import ../_build/checks/check-dedup.nix { inherit pkgs; };
      nixos-exhaustiveness-bin = import ../_build/checks/nixos-exhaustiveness.nix { inherit pkgs; };
      check-specialisation-placement-bin = import ../_build/checks/check-specialisation-placement.nix {
        inherit pkgs;
      };
      check-no-narration-comments-bin = import ../_build/checks/check-no-narration-comments.nix {
        inherit pkgs;
      };
      check-helper-naming-bin = import ../_build/checks/check-helper-naming.nix { inherit pkgs; };
      check-no-with-lib-bin = import ../_build/checks/check-no-with-lib.nix { inherit pkgs; };
      check-no-dated-comments-bin = import ../_build/checks/check-no-dated-comments.nix { inherit pkgs; };
      check-mkforce-comment-bin = import ../_build/checks/check-mkforce-comment.nix { inherit pkgs; };
      check-assertion-format-bin = import ../_build/checks/check-assertion-format.nix { inherit pkgs; };
      check-module-docstring-bin = import ../_build/checks/check-module-docstring.nix { inherit pkgs; };
      check-secrets-leak-bin = import ../_build/checks/check-secrets-leak.nix { inherit pkgs; };
      check-no-cross-tree-import-bin = import ../_build/checks/check-no-cross-tree-import.nix {
        inherit pkgs;
      };
    in
    {
      checks = {
        # site-stub-parity — fails if ci/site-stub stops mirroring the real
        # `site` attribute SHAPE, so a `site` schema change can't silently
        # leave the stub stale (which breaks CI eval — e.g. a missing
        # vfio.* field). Locally `inputs.site` is the real private site
        # (real-vs-stub); in CI `site` is overridden to the stub itself
        # (stub-vs-stub, trivially OK), so the real check runs where the
        # private site exists. Lists are compared as opaque leaves.
        eval-site-stub-parity =
          let
            l = pkgs.lib;
            paths =
              prefix: v:
              if builtins.isAttrs v then
                l.concatLists (l.mapAttrsToList (k: sub: paths (prefix + "." + k) sub) v)
              else
                [ prefix ];
            allPaths = root: l.concatLists (l.mapAttrsToList (k: v: paths k v) root);
            realP = allPaths (import inputs.site);
            stubP = allPaths (import ../../ci/site-stub);
            missing = l.subtractLists stubP realP; # in real site, absent from stub
            extra = l.subtractLists realP stubP; # in stub, absent from real site
            drift =
              l.optionalString (
                missing != [ ]
              ) "\n  MISSING from stub (present in site): ${l.concatStringsSep ", " missing}"
              + l.optionalString (
                extra != [ ]
              ) "\n  EXTRA in stub (absent from site): ${l.concatStringsSep ", " extra}";
          in
          if missing == [ ] && extra == [ ] then
            pkgs.runCommand "eval-site-stub-parity" { } "echo 'OK: ci/site-stub mirrors site shape'; touch $out"
          else
            throw "site-stub drift — ci/site-stub no longer mirrors repos/site shape:${drift}\n  Fix: update ci/site-stub/** to match the site shape (dummy values).";

        # check-placement hook — asserts the hook fires on a synthetic
        # violation (scope mismatch) AND passes on a compliant file. Keeps
        # the hook from becoming vacuously green when the tree is clean.
        check-placement-test =
          pkgs.runCommand "check-placement-test"
            {
              nativeBuildInputs = [ check-placement-bin ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"

              mkdir -p parts/security parts/services
              cp ${./tests/fixtures/placement-violation.nix} parts/security/foo.nix

              # Expect non-zero exit + diagnostic mentioning both scopes.
              if output=$(check-placement parts/security/foo.nix 2>&1); then
                echo "FAIL: check-placement passed the fixture; it should have failed."
                echo "$output"
                exit 1
              fi
              grep -q 'expected scope: myModules.security' <<< "$output" \
                || { echo "FAIL: diagnostic missing expected scope."; echo "$output"; exit 1; }
              grep -q 'actual scope:' <<< "$output" \
                || { echo "FAIL: diagnostic missing actual scope line."; echo "$output"; exit 1; }
              grep -q 'myModules.services' <<< "$output" \
                || { echo "FAIL: diagnostic missing actual scope value."; echo "$output"; exit 1; }

              # Sanity: same content under correct path MUST pass.
              mv parts/security/foo.nix parts/services/foo.nix
              if ! check-placement parts/services/foo.nix; then
                echo "FAIL: check-placement rejected a compliant file."
                exit 1
              fi

              touch "$out"
            '';

        # check-dangling-refs — live gate: scan the real home/modules tree for any
        # unguarded cross-module reference (a module naming another enable-gated
        # module's binary / .desktop id without guarding on its `.enable`). Fails
        # with the offending file + provider + reason (AUDIT.md §19).
        check-dangling-refs =
          pkgs.runCommand "check-dangling-refs"
            {
              nativeBuildInputs = [ check-dangling-refs-bin ];
              src = ../../home/modules;
            }
            ''
              set -euo pipefail
              mkdir -p root/home
              cp -r "$src" root/home/modules
              export DANGLING_ROOT="$PWD/root"
              if ! check-dangling-refs --all; then
                echo "check-dangling-refs: a module references another module's binary/.desktop without guarding on its .enable (AUDIT.md §19)."
                exit 1
              fi
              echo "OK: no unguarded cross-module references in home/modules"
              touch "$out"
            '';

        # check-dangling-refs hook — asserts the checker FIRES on an unguarded
        # reference AND PASSES the guarded form. Keeps the gate non-vacuous.
        check-dangling-refs-test =
          pkgs.runCommand "check-dangling-refs-test"
            {
              nativeBuildInputs = [ check-dangling-refs-bin ];
              violation = ./tests/fixtures/dangling-violation.nix;
              ok = ./tests/fixtures/dangling-ok.nix;
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              export DANGLING_ROOT="$work"
              mkdir -p home/modules/yazi home/modules/editor
              : > home/modules/yazi/default.nix # provider module exists in the universe

              install -m 0644 "$violation" home/modules/editor/default.nix
              if diag=$(check-dangling-refs home/modules/editor/default.nix 2>&1); then
                echo "FAIL: violation fixture passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'editor → yazi' <<< "$diag" \
                || { echo "FAIL: diagnostic missing consumer→provider."; echo "$diag"; exit 1; }
              grep -q 'enable. guard' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the 'no .enable guard' reason."; echo "$diag"; exit 1; }
              grep -q 'fix:' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the fix hint."; echo "$diag"; exit 1; }

              install -m 0644 "$ok" home/modules/editor/default.nix
              if ! check-dangling-refs home/modules/editor/default.nix; then
                echo "FAIL: guarded fixture rejected; expected pass."
                exit 1
              fi
              touch "$out"
            '';

        # check-no-foreign-config — live gate: scan home/modules + parts for any
        # module assigning config into another module's myModules.* namespace
        # (dendritic-invariant violation, AUDIT.md §19).
        check-no-foreign-config =
          pkgs.runCommand "check-no-foreign-config"
            {
              nativeBuildInputs = [ check-no-foreign-config-bin ];
              homeSrc = ../../home/modules;
              partsSrc = ../../parts;
            }
            ''
              set -euo pipefail
              mkdir -p root/home root/parts
              cp -r "$homeSrc" root/home/modules
              cp -r "$partsSrc"/. root/parts/
              export FOREIGN_ROOT="$PWD/root"
              if ! check-no-foreign-config --all; then
                echo "check-no-foreign-config: a module writes into another module's myModules.* namespace (AUDIT.md §19)."
                exit 1
              fi
              echo "OK: no foreign-namespace writes in home/modules or parts"
              touch "$out"
            '';

        # check-no-foreign-config hook — asserts it FIRES on a foreign write AND
        # PASSES an own-namespace write. Keeps the gate non-vacuous.
        check-no-foreign-config-test =
          pkgs.runCommand "check-no-foreign-config-test"
            {
              nativeBuildInputs = [ check-no-foreign-config-bin ];
              violation = ./tests/fixtures/foreign-config-violation.nix;
              ok = ./tests/fixtures/foreign-config-ok.nix;
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              export FOREIGN_ROOT="$work"
              mkdir -p home/modules/editor

              install -m 0644 "$violation" home/modules/editor/default.nix
              if diag=$(check-no-foreign-config home/modules/editor/default.nix 2>&1); then
                echo "FAIL: violation fixture passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'myModules.home.konsole' <<< "$diag" \
                || { echo "FAIL: diagnostic missing target namespace."; echo "$diag"; exit 1; }
              grep -q "another module's domain" <<< "$diag" \
                || { echo "FAIL: diagnostic missing reason."; echo "$diag"; exit 1; }

              install -m 0644 "$ok" home/modules/editor/default.nix
              if ! check-no-foreign-config home/modules/editor/default.nix; then
                echo "FAIL: own-namespace fixture rejected; expected pass."
                exit 1
              fi
              touch "$out"
            '';

        # check-placement — live gate: scan ALL of parts/ + home/modules for
        # file-path ⟺ option-scope mismatches. The pre-commit hook sees only
        # staged files (and --no-verify skips it entirely); this is the
        # unconditional repo-wide scan.
        check-placement =
          pkgs.runCommand "check-placement"
            {
              nativeBuildInputs = [ check-placement-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home/modules;
            }
            ''
              set -euo pipefail
              mkdir -p root/home
              cp -r "$partsSrc" root/parts
              cp -r "$homeSrc" root/home/modules
              cd root
              mapfile -t files < <(find parts home/modules -name '*.nix' | sort)
              if ! check-placement "''${files[@]}"; then
                echo "check-placement: a file's path does not match its option scope (see the scope-picker atop checks/check-placement.nix)."
                exit 1
              fi
              echo "OK: every parts/ + home/modules file matches its option scope"
              touch "$out"
            '';

        # check-dedup — live gate: near-duplicate logic scan over every module
        # tree the pre-commit hook covers (parts, home, lib, ci). Hosts and
        # test fixtures are exempt inside the scanner itself.
        check-dedup =
          pkgs.runCommand "check-dedup"
            {
              nativeBuildInputs = [ check-dedup-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
              libSrc = ../../lib;
              ciSrc = ../../ci;
            }
            ''
              set -euo pipefail
              mkdir root
              cp -r "$partsSrc" root/parts
              cp -r "$homeSrc" root/home
              cp -r "$libSrc" root/lib
              cp -r "$ciSrc" root/ci
              cd root
              mapfile -t files < <(find parts home lib ci -name '*.nix' | sort)
              if ! check-dedup "''${files[@]}"; then
                echo "check-dedup: near-duplicate logic blocks found — extract into a shared helper (or mark a reviewed duplicate with '# dedup-ok')."
                exit 1
              fi
              echo "OK: no near-duplicate logic blocks"
              touch "$out"
            '';

        # check-dedup hook — asserts the detector FIRES on a synthetic clone
        # pair AND honors the `# dedup-ok` suppression. Keeps it non-vacuous.
        check-dedup-test =
          pkgs.runCommand "check-dedup-test"
            {
              nativeBuildInputs = [ check-dedup-bin ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              mkdir -p home/modules/alpha home/modules/beta
              for m in alpha beta; do
                cat > "home/modules/$m/default.nix" <<'EOF'
              {
                lib,
                config,
                pkgs,
                ...
              }:
              {
                config.systemd.services.syntheticClone = {
                  description = "synthetic clone block for the dedup self-test";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network-online.target" ];
                  serviceConfig = {
                    ExecStart = "/run/current-system/sw/bin/synthetic --flag-one --flag-two";
                    Restart = "on-failure";
                    RestartSec = 7;
                    MemoryMax = "512M";
                    CPUQuota = "50%";
                    ProtectSystem = "strict";
                    ProtectHome = true;
                    PrivateTmp = true;
                  };
                };
              }
              EOF
              done

              if diag=$(check-dedup home/modules/alpha/default.nix home/modules/beta/default.nix 2>&1); then
                echo "FAIL: clone pair passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'alpha/default.nix' <<< "$diag" \
                || { echo "FAIL: diagnostic missing file A."; echo "$diag"; exit 1; }
              grep -q 'beta/default.nix' <<< "$diag" \
                || { echo "FAIL: diagnostic missing file B."; echo "$diag"; exit 1; }

              # `# dedup-ok` inside one block's span must suppress the report.
              sed -i '2i # dedup-ok' home/modules/alpha/default.nix
              if ! check-dedup home/modules/alpha/default.nix home/modules/beta/default.nix; then
                echo "FAIL: '# dedup-ok' suppression did not pass the clone pair."
                exit 1
              fi
              touch "$out"
            '';

        # nixos-exhaustiveness — live gate: every host flake-module.nix
        # references every parts/**/*.nix module. The pre-commit hook gates on
        # staged files only; this scans the whole tree (--all).
        nixos-exhaustiveness =
          pkgs.runCommand "nixos-exhaustiveness"
            {
              nativeBuildInputs = [ nixos-exhaustiveness-bin ];
              partsSrc = ../../parts;
            }
            ''
              set -euo pipefail
              mkdir root
              cp -r "$partsSrc" root/parts
              cd root
              if ! nixos-exhaustiveness --all; then
                echo "nixos-exhaustiveness: a host flake-module.nix is missing a module reference (or an exhaustiveness-exclude entry)."
                exit 1
              fi
              touch "$out"
            '';

        # check-specialisation-placement — live gate: no host default.nix may
        # define a specialisation inline; specs live in specialisations/<name>.nix
        # wired by the single myLib.mkSpecialisations call.
        check-specialisation-placement =
          pkgs.runCommand "check-specialisation-placement"
            {
              nativeBuildInputs = [ check-specialisation-placement-bin ];
              partsSrc = ../../parts;
            }
            ''
              set -euo pipefail
              mkdir root
              cp -r "$partsSrc" root/parts
              cd root
              if ! check-specialisation-placement; then
                echo "check-specialisation-placement: a host default.nix defines a specialisation inline."
                exit 1
              fi
              echo "OK: no inline specialisations in host default.nix files"
              touch "$out"
            '';

        # check-specialisation-placement hook — asserts the gate FIRES on an
        # inline spec AND PASSES the mkSpecialisations wiring. Non-vacuous.
        check-specialisation-placement-test =
          pkgs.runCommand "check-specialisation-placement-test"
            {
              nativeBuildInputs = [ check-specialisation-placement-bin ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"

              cat > inline-spec.nix <<'EOF'
              {
                specialisation.vfio-x.configuration = {
                  boot.kernelParams = [ "iommu=pt" ];
                };
              }
              EOF
              if diag=$(check-specialisation-placement inline-spec.nix 2>&1); then
                echo "FAIL: inline specialisation passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'specialisation.vfio-x' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the inline spec."; echo "$diag"; exit 1; }
              grep -q 'mkSpecialisations' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the fix hint."; echo "$diag"; exit 1; }

              cat > wired-spec.nix <<'EOF'
              {
                # Reads like config.specialisation.foo and comments about
                # specialisation.bar must not trip the gate.
                specialisation = myLib.mkSpecialisations { dir = ./specialisations; };
              }
              EOF
              if ! check-specialisation-placement wired-spec.nix; then
                echo "FAIL: mkSpecialisations wiring rejected; expected pass."
                exit 1
              fi
              touch "$out"
            '';

        # check-helper-naming — live gate: every domain-level parts/<domain>/*.nix
        # is a module or a `_`-prefixed helper.
        check-helper-naming =
          pkgs.runCommand "check-helper-naming"
            {
              nativeBuildInputs = [ check-helper-naming-bin ];
              partsSrc = ../../parts;
            }
            ''
              set -euo pipefail
              mkdir root
              cp -r "$partsSrc" root/parts
              cd root
              if ! check-helper-naming --all; then
                echo "check-helper-naming: an un-categorised file sits at the parts/<domain>/ level."
                exit 1
              fi
              echo "OK: every domain-level parts file is a module or a _-prefixed helper"
              touch "$out"
            '';

        # check-helper-naming hook — asserts it FIRES on a bare helper AND PASSES
        # a module and a _-prefixed helper. Keeps it non-vacuous.
        check-helper-naming-test =
          pkgs.runCommand "check-helper-naming-test"
            {
              nativeBuildInputs = [ check-helper-naming-bin ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              mkdir -p parts/widgets

              # A bare, un-categorised helper → must fail.
              printf '{ x = 1; }\n' > parts/widgets/helper.nix
              if diag=$(check-helper-naming parts/widgets/helper.nix 2>&1); then
                echo "FAIL: bare helper passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'parts/widgets/helper.nix' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the file."; echo "$diag"; exit 1; }

              # A _-prefixed helper → must pass.
              printf '{ x = 1; }\n' > parts/widgets/_helper.nix
              if ! check-helper-naming parts/widgets/_helper.nix; then
                echo "FAIL: _-prefixed helper rejected."
                exit 1
              fi

              # A real module (flake.modules.* on its own line, as in-tree) → must pass.
              printf '{\n  flake.modules.nixos.widgets-foo = { };\n}\n' > parts/widgets/foo.nix
              if ! check-helper-naming parts/widgets/foo.nix; then
                echo "FAIL: module rejected."
                exit 1
              fi
              touch "$out"
            '';

        # check-no-narration-comments — live gate: scan every tracked
        # .nix/.sh/.py for change-narration prose in comments.
        check-no-narration-comments =
          pkgs.runCommand "check-no-narration-comments"
            {
              nativeBuildInputs = [ check-no-narration-comments-bin ];
              src = ../../.;
            }
            ''
              set -euo pipefail
              cp -r "$src" root
              cd root
              # The flake source has no .git; feed the file list directly.
              mapfile -t files < <(
                find parts home lib ci -type f \
                  \( -name '*.nix' -o -name '*.sh' -o -name '*.py' \) \
                  | grep -vE 'tests/fixtures' | sort
              )
              if ! check-no-narration-comments "''${files[@]}"; then
                echo "check-no-narration-comments: change-narration found in a comment."
                exit 1
              fi
              echo "OK: no change-narration comments"
              touch "$out"
            '';

        # check-no-narration-comments hook — asserts it FIRES on a narration
        # comment AND honors the `# narration-ok` waiver. Keeps it non-vacuous.
        check-no-narration-comments-test =
          pkgs.runCommand "check-no-narration-comments-test"
            {
              nativeBuildInputs = [ check-no-narration-comments-bin ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              printf '{\n  # moved from the dissolved base module\n  x = 1;\n}\n' > bad.nix # narration-ok: gate self-test fixture
              if diag=$(check-no-narration-comments bad.nix 2>&1); then
                echo "FAIL: narration comment passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'bad.nix' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the file."; echo "$diag"; exit 1; }

              printf '{\n  # moved from the dissolved base module  # narration-ok: keep\n  x = 1;\n}\n' > waived.nix # narration-ok: gate self-test fixture
              if ! check-no-narration-comments waived.nix; then
                echo "FAIL: '# narration-ok' waiver did not pass."
                exit 1
              fi

              printf '{\n  # Pins the bridge to the 5GbE uplink (kernel needs it at boot).\n  x = 1;\n}\n' > good.nix
              if ! check-no-narration-comments good.nix; then
                echo "FAIL: clean comment rejected."
                exit 1
              fi
              touch "$out"
            '';

        # nixos-exhaustiveness hook — asserts the gate FIRES when a host omits
        # a module AND PASSES once the reference exists. Keeps it non-vacuous.
        nixos-exhaustiveness-test =
          pkgs.runCommand "nixos-exhaustiveness-test"
            {
              nativeBuildInputs = [ nixos-exhaustiveness-bin ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              mkdir -p parts/services parts/hosts/h1
              cat > parts/services/foo.nix <<'EOF'
              {
                flake.modules.nixos.services-foo = { };
              }
              EOF
              printf '{ }\n' > parts/hosts/h1/flake-module.nix

              if diag=$(nixos-exhaustiveness --all 2>&1); then
                echo "FAIL: host missing a module reference passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'services-foo' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the module name."; echo "$diag"; exit 1; }

              printf '{ imports = [ inputs.self.modules.nixos.services-foo ]; }\n' \
                > parts/hosts/h1/flake-module.nix
              if ! nixos-exhaustiveness --all; then
                echo "FAIL: exhaustive host rejected; expected pass."
                exit 1
              fi
              touch "$out"
            '';

        # ── Comment-standard / style / security gates — live whole-tree scans ──
        # Each mirrors a pre-commit hook (staged) via the SAME script run with
        # --all, plus a failure-injection self-test. This is what makes the
        # comment standard enforced in CI (the pre-commit side is --no-verify-able).

        check-no-with-lib =
          pkgs.runCommand "check-no-with-lib"
            {
              nativeBuildInputs = [ check-no-with-lib-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
              libSrc = ../../lib;
              ciSrc = ../../ci;
            }
            ''
              set -euo pipefail
              mkdir root && cp -r "$partsSrc" root/parts && cp -r "$homeSrc" root/home \
                && cp -r "$libSrc" root/lib && cp -r "$ciSrc" root/ci
              cd root
              if ! check-no-with-lib --all; then echo "check-no-with-lib: 'with lib;' present"; exit 1; fi
              echo "OK: no 'with lib;'"; touch "$out"
            '';
        check-no-with-lib-test =
          pkgs.runCommand "check-no-with-lib-test" { nativeBuildInputs = [ check-no-with-lib-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf '{ lib, ... }:\nwith lib;\n{ x = 1; }\n' > bad.nix
              if check-no-with-lib bad.nix; then echo "FAIL: 'with lib;' passed"; exit 1; fi
              printf '{ lib, ... }:\n{ x = lib.mkIf true 1; }\n' > good.nix
              if ! check-no-with-lib good.nix; then echo "FAIL: clean file rejected"; exit 1; fi
              touch "$out"
            '';

        check-no-dated-comments =
          pkgs.runCommand "check-no-dated-comments"
            {
              nativeBuildInputs = [ check-no-dated-comments-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
              libSrc = ../../lib;
              ciSrc = ../../ci;
            }
            ''
              set -euo pipefail
              mkdir root && cp -r "$partsSrc" root/parts && cp -r "$homeSrc" root/home \
                && cp -r "$libSrc" root/lib && cp -r "$ciSrc" root/ci
              cd root
              if ! check-no-dated-comments --all; then echo "check-no-dated-comments: dated comment present"; exit 1; fi
              echo "OK: no dated comments"; touch "$out"
            '';
        check-no-dated-comments-test =
          pkgs.runCommand "check-no-dated-comments-test"
            { nativeBuildInputs = [ check-no-dated-comments-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf '{\n  # fixed on 2026-06-10 by hand\n  x = 1;\n}\n' > bad.nix
              if check-no-dated-comments bad.nix; then echo "FAIL: dated comment passed"; exit 1; fi
              printf '{\n  # pins the bridge to the 5GbE uplink\n  x = 1;\n}\n' > good.nix
              if ! check-no-dated-comments good.nix; then echo "FAIL: clean rejected"; exit 1; fi
              touch "$out"
            '';

        check-mkforce-comment =
          pkgs.runCommand "check-mkforce-comment"
            {
              nativeBuildInputs = [ check-mkforce-comment-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
              libSrc = ../../lib;
              ciSrc = ../../ci;
            }
            ''
              set -euo pipefail
              mkdir root && cp -r "$partsSrc" root/parts && cp -r "$homeSrc" root/home \
                && cp -r "$libSrc" root/lib && cp -r "$ciSrc" root/ci
              cd root
              if ! check-mkforce-comment --all; then echo "check-mkforce-comment: unjustified mkForce"; exit 1; fi
              echo "OK: every mkForce has a # Why:"; touch "$out"
            '';
        check-mkforce-comment-test =
          pkgs.runCommand "check-mkforce-comment-test" { nativeBuildInputs = [ check-mkforce-comment-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf '{ lib, ... }:\n{\n  services.x.enable = lib.mkForce false;\n}\n' > bad.nix
              if check-mkforce-comment bad.nix; then echo "FAIL: bare mkForce passed"; exit 1; fi
              printf '{ lib, ... }:\n{\n  # Why: upstream forces it on; we need it off here.\n  services.x.enable = lib.mkForce false;\n}\n' > good.nix
              if ! check-mkforce-comment good.nix; then echo "FAIL: justified mkForce rejected"; exit 1; fi
              touch "$out"
            '';

        check-assertion-format =
          pkgs.runCommand "check-assertion-format"
            {
              nativeBuildInputs = [ check-assertion-format-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
              libSrc = ../../lib;
              ciSrc = ../../ci;
            }
            ''
              set -euo pipefail
              mkdir root && cp -r "$partsSrc" root/parts && cp -r "$homeSrc" root/home \
                && cp -r "$libSrc" root/lib && cp -r "$ciSrc" root/ci
              cd root
              if ! check-assertion-format --all; then echo "check-assertion-format: assertion message missing myModules.*"; exit 1; fi
              echo "OK: assertion messages name their option"; touch "$out"
            '';
        check-assertion-format-test =
          pkgs.runCommand "check-assertion-format-test"
            { nativeBuildInputs = [ check-assertion-format-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf '{\n  assertions = [\n    {\n      assertion = false;\n      message = "something broke";\n    }\n  ];\n}\n' > bad.nix
              if check-assertion-format bad.nix; then echo "FAIL: bad assertion message passed"; exit 1; fi
              printf '{\n  assertions = [\n    {\n      assertion = false;\n      message = "myModules.x.y: must be set";\n    }\n  ];\n}\n' > good.nix
              if ! check-assertion-format good.nix; then echo "FAIL: good assertion rejected"; exit 1; fi
              touch "$out"
            '';

        check-module-docstring =
          pkgs.runCommand "check-module-docstring"
            {
              nativeBuildInputs = [ check-module-docstring-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
            }
            ''
              set -euo pipefail
              mkdir -p root && cp -r "$partsSrc" root/parts && cp -r "$homeSrc" root/home
              cd root
              if ! check-module-docstring --all; then echo "check-module-docstring: module missing docstring"; exit 1; fi
              echo "OK: modules have docstrings"; touch "$out"
            '';
        check-module-docstring-test =
          pkgs.runCommand "check-module-docstring-test"
            { nativeBuildInputs = [ check-module-docstring-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"; mkdir -p parts/widgets
              # >10 lines, first line not a comment → must fail.
              { echo '{ lib, ... }:'; echo '{'; for i in $(seq 1 12); do echo "  o$i = $i;"; done; echo '}'; } > parts/widgets/foo.nix
              if check-module-docstring parts/widgets/foo.nix; then echo "FAIL: undocumented module passed"; exit 1; fi
              { echo '# foo — a widget.'; echo '{ lib, ... }:'; echo '{'; for i in $(seq 1 12); do echo "  o$i = $i;"; done; echo '}'; } > parts/widgets/bar.nix
              if ! check-module-docstring parts/widgets/bar.nix; then echo "FAIL: documented module rejected"; exit 1; fi
              touch "$out"
            '';

        check-secrets-leak =
          pkgs.runCommand "check-secrets-leak"
            {
              nativeBuildInputs = [ check-secrets-leak-bin ];
              src = ../../.;
            }
            ''
              set -euo pipefail
              cp -r "$src" root && cd root
              if ! check-secrets-leak --all; then echo "check-secrets-leak: forbidden path present"; exit 1; fi
              echo "OK: no secret material in the tree"; touch "$out"
            '';
        check-secrets-leak-test =
          pkgs.runCommand "check-secrets-leak-test" { nativeBuildInputs = [ check-secrets-leak-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              : > host.age
              if check-secrets-leak host.age; then echo "FAIL: .age path passed"; exit 1; fi
              : > ok.nix
              if ! check-secrets-leak ok.nix; then echo "FAIL: clean path rejected"; exit 1; fi
              touch "$out"
            '';

        check-no-cross-tree-import =
          pkgs.runCommand "check-no-cross-tree-import"
            {
              nativeBuildInputs = [ check-no-cross-tree-import-bin ];
              partsSrc = ../../parts;
              homeSrc = ../../home;
            }
            ''
              set -euo pipefail
              mkdir -p root && cp -r "$partsSrc" root/parts && cp -r "$homeSrc" root/home
              cd root
              if ! check-no-cross-tree-import --all; then echo "check-no-cross-tree-import: cross-tree relative import"; exit 1; fi
              echo "OK: no cross-tree relative imports"; touch "$out"
            '';
        check-no-cross-tree-import-test =
          pkgs.runCommand "check-no-cross-tree-import-test"
            { nativeBuildInputs = [ check-no-cross-tree-import-bin ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"; mkdir -p parts/desktop
              printf '{\n  imports = [ ../../home/modules/foo ];\n}\n' > parts/desktop/bad.nix
              if check-no-cross-tree-import parts/desktop/bad.nix; then echo "FAIL: cross-tree import passed"; exit 1; fi
              printf '{\n  imports = [ ../vfio/_lib.nix ];\n}\n' > parts/desktop/ok.nix
              if ! check-no-cross-tree-import parts/desktop/ok.nix; then echo "FAIL: within-tree relative import rejected"; exit 1; fi
              touch "$out"
            '';

        # Toplevel host evals live in CI workflow (nix eval), not here.
        # nix flake check --no-build can't handle IFD in system closures
        # (references.nix is an import-from-derivation). nix eval can.

        consumer-nixos-import =
          let
            testCfg = inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                inputs.self.modules.nixos.hardware-pipewire
                { myModules.hardware.pipewire.enable = true; }
              ];
            };
          in
          pkgs.runCommand "consumer-nixos-import" { } ''
            echo "NixOS module import: hardware-pipewire evaluated successfully"
            echo "pipewire.enable = ${builtins.toString testCfg.config.myModules.hardware.pipewire.enable}"
            touch $out
          '';

        consumer-hm-module-count =
          let
            moduleNames = builtins.attrNames inputs.self.homeModules;
            count = builtins.length moduleNames;
          in
          pkgs.runCommand "consumer-hm-module-count"
            {
              inherit count;
            }
            ''
              echo "homeModules exports $count modules"
              if [ "$count" -lt 100 ]; then
                echo "FAIL: expected 100+ homeModules, got $count"
                exit 1
              fi
              echo "OK: $count homeModules exported"
              touch $out
            '';

        # Verify nix daemon + user creation in one VM boot (merged from
        # vm-nix-settings + vm-users — identical base modules, one boot).
        vm-core = pkgs.testers.nixosTest {
          name = "core";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.nix-nix
              inputs.self.modules.nixos.users
            ];
            virtualisation.memorySize = 512;
            virtualisation.graphics = false;
            myModules.nix.nix.enable = true;
            myModules.users.enable = true;
            myModules.primaryUser = "testuser";
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Nix daemon + settings
            machine.wait_for_unit("nix-daemon.service")
            machine.succeed("nix --version")
            machine.succeed("nix show-config | grep experimental-features | grep flakes")
            machine.succeed("nix show-config | grep experimental-features | grep cgroups")
            machine.succeed("nix show-config | grep auto-optimise-store | grep true")

            # User creation, groups, shell
            machine.succeed("id testuser")
            machine.succeed("id -nG testuser | grep -q wheel")
            machine.succeed("id -nG testuser | grep -q video")
            machine.succeed("getent passwd testuser | grep -q zsh")
          '';
        };

        # Verify SSH hardening and fail2ban
        vm-ssh = pkgs.testers.nixosTest {
          name = "ssh";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.security-ssh
              inputs.self.modules.nixos.users
            ];
            virtualisation.memorySize = 512;
            virtualisation.graphics = false;
            myModules.security.ssh.enable = true;
            myModules.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("sshd.service")
            machine.wait_for_unit("fail2ban.service")

            # Verify hardened settings
            machine.succeed("sshd -T | grep -qi 'passwordauthentication no'")
            machine.succeed("sshd -T | grep -qi 'x11forwarding no'")
            machine.succeed("sshd -T | grep -qi 'maxauthtries 3'")

            # Verify firewall allows SSH
            machine.succeed("ss -tlnp | grep -q ':22'")
          '';
        };

        # Verify NetworkManager + systemd-resolved DoT in one VM boot
        # (merged from vm-networking + vm-networking-resolved — same modules).
        vm-networking = pkgs.testers.nixosTest {
          name = "networking";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.hardware-networking
              inputs.self.modules.nixos.users
            ];
            virtualisation.memorySize = 512;
            virtualisation.graphics = false;
            myModules.hardware.networking = {
              enable = true;
              dnsOverTls = "opportunistic";
            };
            myModules.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("NetworkManager.service")
            machine.succeed("nmcli general status")
            machine.succeed("systemctl is-active systemd-resolved.service")

            # DNS-over-TLS configured (not "no")
            machine.succeed("resolvectl status | grep -i 'DNSOverTLS' | grep -iv 'no'")
            # Stub resolver listening
            machine.succeed("ss -tlnp | grep '127.0.0.53'")
          '';
        };

        # ── Test backfill — high-blast-radius modules ──
        # Covers modules whose silent failures would break an entire host.
        # Kept minimal: activation + one key behavior.

        # security-agenix — agenix package provisioning + age key path.
        # Cannot test actual secret decryption in VM (no host SSH key).
        # Validates that the module activates and the CLI tools are available.
        vm-security-agenix = pkgs.testers.nixosTest {
          name = "security-agenix";
          nodes.machine =
            { ... }:
            {
              imports = [
                inputs.agenix.nixosModules.default
                inputs.self.modules.nixos.security-agenix
                inputs.self.modules.nixos.users
              ];
              virtualisation.memorySize = 512;
              virtualisation.graphics = false;
              myModules.users.enable = true;
              myModules.security.agenix = {
                enable = true;
              };
            };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.succeed("which agenix")
            machine.succeed("which age")
          '';
        };

        # boot-impermanence — initrd rollback service definition + option
        # wiring. Cannot test actual rollback in VM (needs btrfs + reboot),
        # but validates the service derivation is generated when enabled.
        vm-boot-impermanence = pkgs.testers.nixosTest {
          name = "boot-impermanence";
          nodes.machine =
            { ... }:
            {
              imports = [
                inputs.impermanence.nixosModules.impermanence
                inputs.self.modules.nixos.boot-impermanence
                inputs.self.modules.nixos.users
              ];
              virtualisation.memorySize = 512;
              virtualisation.graphics = false;
              myModules.users.enable = true;
              myModules.boot.impermanence = {
                enable = true;
                # Point at a VM-safe path; rollback service won't actually run
                # (no btrfs device in VM) but unit file must exist.
                persistPath = "/persist";
                extraDirectories = [ "/var/log" ];
              };
              # Skip actual disk layout; VM uses default filesystem
              fileSystems."/persist" = {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [ "mode=0755" ];
                neededForBoot = true;
              };
            };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            # Persist mountpoint exists
            machine.succeed("test -d /persist")
            # extraDirectories wires up a bind mount from /persist/<dir>
            # to <dir>. After activation /persist/var/log must exist —
            # if impermanence didn't create it, this fails loudly (no
            # fallback `|| mkdir -p`, which would mask a real regression).
            machine.succeed("test -d /persist/var/log")
            # The bind mount means /var/log and /persist/var/log share
            # the same inode. Confirm the link is live, not accidental.
            machine.succeed("findmnt -n -o SOURCE /var/log | grep -q /persist")
          '';
        };

        # hardware-graphics — mesaGit override path exercises mkForce on
        # hardware.graphics.package. Eval-time check (module outputs correct
        # derivation) rather than VM test (no GPU in headless VM).
        #
        # Assertion strategy: mesa-git KEEPS pname="mesa" (it's still the
        # mesa package, just built from git). What differs is version —
        # git builds have "-devel-" in the version string (e.g.
        # "26.2.0-devel-8736d1a"). Checking this catches the real
        # regression: if mkForce fails or the mesa-git overlay isn't
        # applied, version falls back to nixpkgs stable (no "-devel-").
        # hardware-pipewire — PipeWire service starts, LADSPA search path
        # populated, wireplumber running. Cannot test actual audio in VM
        # but catches the LADSPA_PATH / SPA symbol regressions.
        vm-hardware-pipewire = pkgs.testers.nixosTest {
          name = "hardware-pipewire";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.hardware-pipewire
              inputs.self.modules.nixos.users
            ];
            virtualisation.memorySize = 512;
            virtualisation.graphics = false;
            myModules.hardware.pipewire = {
              enable = true;
              extraLadspaPackages = [ pkgs.deepfilternet ];
            };
            myModules.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            # PipeWire system service socket exists
            machine.succeed("test -S /run/pipewire/pipewire-0 || systemctl --user -M user@ is-active pipewire.service")
            # LADSPA plugin config wired into PipeWire — no store-path fallback
            machine.succeed("grep -r 'ladspa' /etc/pipewire/pipewire.conf.d/ 2>/dev/null | grep -qv '^#'")
          '';
        };

        # eval-kernel-cachyos — CachyOS kernel is active on ryzen host.
        # Catches regressions where kernel overlay or input pin breaks
        # and silently falls back to stock nixpkgs kernel.
        eval-kernel-cachyos =
          let
            kpkg = inputs.self.nixosConfigurations.ryzen-9950x3d.config.boot.kernelPackages.kernel;
          in
          pkgs.runCommand "eval-kernel-cachyos"
            {
              actual = kpkg.pname;
              inherit (kpkg) version;
            }
            ''
              echo "kernel.pname = $actual  version = $version"
              case "$actual" in
                *cachyos*)
                  echo "OK: CachyOS kernel active"
                  touch $out
                  ;;
                *)
                  echo "FAIL: expected pname containing 'cachyos', got '$actual'"
                  echo "Overlay may have fallen back to stock nixpkgs kernel"
                  exit 1
                  ;;
              esac
            '';

        eval-hardware-graphics-mesa-git =
          let
            inherit (inputs.self.nixosConfigurations.ryzen-9950x3d.config.hardware.graphics.package) version;
          in
          pkgs.runCommand "eval-hardware-graphics-mesa-git"
            {
              actual = version;
            }
            ''
              echo "hardware.graphics.package.version = $actual"
              case "$actual" in
                *-devel-*)
                  echo "OK: mesa-git active (version contains -devel-)"
                  touch $out
                  ;;
                *)
                  echo "FAIL: expected mesa-git (version string matching *-devel-*)"
                  echo "Got: $actual — looks like nixpkgs stable mesa"
                  echo "mkForce may not have fired, or mesa-git overlay not applied."
                  exit 1
                  ;;
              esac
            '';

        # myLib.mkSimplePackage — contract: factory is a function that
        # accepts {name,description} and returns a module function.
        eval-mylib-mkSimplePackage =
          let
            factory = inputs.self.lib.mkSimplePackage;
            mod = factory {
              name = "test-dummy";
              description = "contract test";
            };
            isFunc = builtins.isFunction mod;
          in
          pkgs.runCommand "eval-mylib-mkSimplePackage" { } (
            if isFunc then
              ''
                echo "OK: mkSimplePackage returns a function (valid module shape)"
                touch $out
              ''
            else
              ''
                echo "FAIL: mkSimplePackage did not return a function"
                exit 1
              ''
          );

        # myLib.mergeSettings — contract: overrides win over defaults,
        # nested attrs merge recursively.
        eval-mylib-mergeSettings =
          let
            merge = inputs.self.lib.mergeSettings;
            merged = merge {
              defaults = {
                a = 1;
                b = 2;
                nested.x = 10;
              };
              overrides = {
                b = 99;
                nested.y = 20;
              };
            };
            pass = merged.a == 1 && merged.b == 99 && merged.nested.x == 10 && merged.nested.y == 20;
          in
          pkgs.runCommand "eval-mylib-mergeSettings" { } (
            if pass then
              ''
                echo "OK: mergeSettings override semantics correct"
                echo "  a=1 (kept), b=99 (overridden), nested.x=10 (kept), nested.y=20 (added)"
                touch $out
              ''
            else
              ''
                echo "FAIL: mergeSettings produced wrong result"
                exit 1
              ''
          );
        # myLib.mkSettingsOption — contract: returns an option with
        # attrsOf anything type and empty default.
        eval-mylib-mkSettingsOption =
          let
            opt = inputs.self.lib.mkSettingsOption { };
            hasType = opt ? type;
            hasDefault = opt ? default && opt.default == { };
          in
          pkgs.runCommand "eval-mylib-mkSettingsOption" { } (
            if hasType && hasDefault then
              ''
                echo "OK: mkSettingsOption produces option with type + empty default"
                touch $out
              ''
            else
              ''
                echo "FAIL: mkSettingsOption missing type or default"
                exit 1
              ''
          );

        # myLib.themeCtx — contract: returns hasTheme/c/theme attrs,
        # handles missing theme gracefully.
        eval-mylib-themeCtx =
          let
            ctx = inputs.self.lib.themeCtx {
              config.myModules.home.theme = { };
            };
            pass = !ctx.hasTheme && ctx.c == { };
          in
          pkgs.runCommand "eval-mylib-themeCtx" { } (
            if pass then
              ''
                echo "OK: themeCtx handles disabled theme (hasTheme=false, c={})"
                touch $out
              ''
            else
              ''
                echo "FAIL: themeCtx contract violation"
                exit 1
              ''
          );

        # myLib.withStdenvCC — contract: returns a derivation with
        # stdenv.cc in nativeBuildInputs.
        eval-mylib-withStdenvCC =
          let
            dummy = pkgs.runCommand "dummy-drv" { } "touch $out";
            result = inputs.self.lib.withStdenvCC {
              inherit pkgs;
              drv = dummy;
            };
            hasCC = builtins.elem pkgs.stdenv.cc (result.nativeBuildInputs or [ ]);
          in
          pkgs.runCommand "eval-mylib-withStdenvCC" { } (
            if hasCC then
              ''
                echo "OK: withStdenvCC injects stdenv.cc into nativeBuildInputs"
                touch $out
              ''
            else
              ''
                echo "FAIL: stdenv.cc not found in nativeBuildInputs"
                exit 1
              ''
          );

        # ── Eval canaries — high-blast-radius module property assertions ──
        # Instant (<1s), catch silent-fallback regressions before VM tests.

        eval-security-hardening =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-security-hardening"
            {
              enabled = builtins.toJSON cfg.myModules.security.hardening.enable;
              polkit = builtins.toJSON cfg.security.polkit.enable;
              rtkit = builtins.toJSON cfg.security.rtkit.enable;
            }
            ''
              echo "myModules.security.hardening.enable = $enabled"
              echo "security.polkit.enable = $polkit"
              echo "security.rtkit.enable = $rtkit"
              [[ "$enabled" == "true" ]] || { echo "FAIL: hardening not enabled"; exit 1; }
              [[ "$polkit" == "true" ]] || { echo "FAIL: polkit not enabled by hardening"; exit 1; }
              [[ "$rtkit" == "true" ]] || { echo "FAIL: rtkit not enabled by hardening"; exit 1; }
              echo "OK: hardening active (polkit + rtkit)"
              touch $out
            '';

        eval-boot-lanzaboote =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-boot-lanzaboote"
            {
              lanzaboote = builtins.toJSON (cfg.boot.lanzaboote.enable or false);
              sdBoot = builtins.toJSON cfg.boot.loader.systemd-boot.enable;
              pkiBundle = cfg.boot.lanzaboote.pkiBundle or "unset";
            }
            ''
              [[ "$lanzaboote" == "true" ]] || { echo "FAIL: lanzaboote not enabled"; exit 1; }
              [[ "$sdBoot" == "false" ]] || { echo "FAIL: systemd-boot still enabled — conflicts with lanzaboote"; exit 1; }
              [[ "$pkiBundle" == "/var/lib/sbctl" ]] || { echo "FAIL: pkiBundle is '$pkiBundle', expected /var/lib/sbctl"; exit 1; }
              echo "OK: lanzaboote active, systemd-boot disabled, pki at /var/lib/sbctl"
              touch $out
            '';

        eval-services-earlyoom =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-services-earlyoom"
            {
              enabled = builtins.toJSON cfg.services.earlyoom.enable;
            }
            ''
              echo "services.earlyoom.enable = $enabled"
              [[ "$enabled" == "true" ]] || { echo "FAIL: earlyoom not enabled"; exit 1; }
              echo "OK: earlyoom active"
              touch $out
            '';

        eval-nix-flakes =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
            features = cfg.nix.settings.experimental-features;
          in
          pkgs.runCommand "eval-nix-flakes"
            {
              hasFlakes = builtins.toJSON (builtins.elem "flakes" features);
              hasNixCmd = builtins.toJSON (builtins.elem "nix-command" features);
            }
            ''
              echo "has flakes = $hasFlakes"
              echo "has nix-command = $hasNixCmd"
              [[ "$hasFlakes" == "true" ]] || { echo "FAIL: flakes not in experimental-features"; exit 1; }
              [[ "$hasNixCmd" == "true" ]] || { echo "FAIL: nix-command not in experimental-features"; exit 1; }
              echo "OK: flakes + nix-command active"
              touch $out
            '';

        eval-hardware-networking =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-hardware-networking"
            {
              nm = builtins.toJSON cfg.networking.networkmanager.enable;
            }
            ''
              echo "networking.networkmanager.enable = $nm"
              [[ "$nm" == "true" ]] || { echo "FAIL: NetworkManager not enabled"; exit 1; }
              echo "OK: NetworkManager active"
              touch $out
            '';

        eval-users-zsh =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
            user = cfg.myModules.primaryUser;
            shell = cfg.users.users.${user}.shell.pname;
          in
          pkgs.runCommand "eval-users-zsh"
            {
              actual = shell;
              inherit user;
            }
            ''
              echo "users.users.$user.shell.pname = $actual"
              [[ "$actual" == "zsh" ]] || { echo "FAIL: user $user shell is $actual, expected zsh"; exit 1; }
              echo "OK: user $user has zsh shell"
              touch $out
            '';

        eval-portmaster-dns-interception =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
            forced = cfg.myModules.security.portmaster.forceSettings;
          in
          pkgs.runCommand "eval-portmaster-dns-interception"
            {
              intercept = builtins.toJSON (forced."filter/dnsQueryInterception" or true);
            }
            ''
              [[ "$intercept" == "false" ]] \
                || { echo "FAIL: dnsQueryInterception not forced off — Mullvad deadlock risk"; exit 1; }
              echo "OK: Portmaster DNS interception forced off"
              touch $out
            '';

        eval-vfio-iommu-params =
          let
            params = inputs.self.nixosConfigurations.ryzen-9950x3d.config.boot.kernelParams;
          in
          pkgs.runCommand "eval-vfio-iommu-params"
            {
              hasIommu = builtins.toJSON (builtins.elem "amd_iommu=on" params);
              hasPt = builtins.toJSON (builtins.elem "iommu=pt" params);
            }
            ''
              [[ "$hasIommu" == "true" ]] || { echo "FAIL: amd_iommu=on missing from kernelParams"; exit 1; }
              [[ "$hasPt" == "true" ]] || { echo "FAIL: iommu=pt missing from kernelParams"; exit 1; }
              echo "OK: IOMMU params present for VFIO"
              touch $out
            '';

        eval-scx-scheduler =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-scx-scheduler"
            {
              actual = cfg.services.scx.scheduler;
            }
            ''
              [[ "$actual" == "scx_bpfland" ]] \
                || { echo "FAIL: scx scheduler is '$actual', expected scx_bpfland (scx_lavd has crash bugs)"; exit 1; }
              echo "OK: scx_bpfland active"
              touch $out
            '';

        eval-mullvad-lockdown =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-mullvad-lockdown"
            {
              lockdown = builtins.toJSON (cfg.myModules.services.mullvad.settings.lockdownMode or false);
              autoConn = builtins.toJSON (cfg.myModules.services.mullvad.settings.autoConnect or false);
            }
            ''
              [[ "$lockdown" == "true" ]] || { echo "FAIL: lockdownMode not enabled — real IP exposed at boot"; exit 1; }
              [[ "$autoConn" == "true" ]] || { echo "FAIL: autoConnect not enabled — tunnel requires manual start"; exit 1; }
              echo "OK: Mullvad always-on kill-switch active"
              touch $out
            '';

        eval-networking-dot =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-networking-dot"
            {
              dot = cfg.services.resolved.settings.Resolve.DNSOverTLS or "unset";
            }
            ''
              [[ "$dot" == "opportunistic" ]] || { echo "FAIL: DNSOverTLS is '$dot', expected 'opportunistic'"; exit 1; }
              echo "OK: DNS-over-TLS set to opportunistic"
              touch $out
            '';

        eval-nix-trusted-users =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
            trusted = cfg.nix.settings.trusted-users;
            user = cfg.myModules.primaryUser;
          in
          pkgs.runCommand "eval-nix-trusted-users"
            {
              hasPrimary = builtins.toJSON (builtins.elem user trusted);
              hasRoot = builtins.toJSON (builtins.elem "root" trusted);
            }
            ''
              [[ "$hasPrimary" == "true" ]] || { echo "FAIL: primaryUser not in trusted-users"; exit 1; }
              [[ "$hasRoot" == "true" ]] || { echo "FAIL: root not in trusted-users"; exit 1; }
              echo "OK: primaryUser + root in nix trusted-users"
              touch $out
            '';

        eval-kernel-modules-vfio =
          let
            mods = inputs.self.nixosConfigurations.ryzen-9950x3d.config.boot.kernelModules;
          in
          pkgs.runCommand "eval-kernel-modules-vfio"
            {
              hasVfio = builtins.toJSON (builtins.elem "vfio-pci" mods);
              hasKvm = builtins.toJSON (builtins.elem "kvm-amd" mods);
            }
            ''
              [[ "$hasVfio" == "true" ]] || { echo "FAIL: vfio-pci not in kernelModules"; exit 1; }
              [[ "$hasKvm" == "true" ]] || { echo "FAIL: kvm-amd not in kernelModules"; exit 1; }
              echo "OK: VFIO kernel modules present"
              touch $out
            '';

        eval-x3d-vcache-mode =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-x3d-vcache-mode"
            {
              inherit (cfg.myModules.hardware.cpuAmd.x3dVcache) mode;
            }
            ''
              [[ "$mode" == "cache" ]] || { echo "FAIL: x3dVcache mode is '$mode', expected 'cache'"; exit 1; }
              echo "OK: X3D V-Cache in cache mode"
              touch $out
            '';

        eval-mbp-kernel-cachyos-lto =
          let
            cfg = inputs.self.nixosConfigurations.macbook-pro-9-2.config;
            variant = cfg.myModules.boot.kernel.variant;
            sched = cfg.myModules.boot.kernel.cachyos.cpusched;
            specCount = builtins.length (builtins.attrNames (cfg.specialisation or { }));
          in
          pkgs.runCommand "eval-mbp-kernel-cachyos-lto"
            {
              inherit variant sched;
              specCount = builtins.toString specCount;
            }
            ''
              [[ "$variant" == "cachyos-lto" ]] || { echo "FAIL: MBP kernel variant is '$variant', expected 'cachyos-lto'"; exit 1; }
              [[ "$sched" == "bore" ]]          || { echo "FAIL: MBP cpusched is '$sched', expected 'bore'"; exit 1; }
              [[ "$specCount" == "0" ]]         || { echo "FAIL: MBP has $specCount specialisation(s); single-kernel design expects 0"; exit 1; }
              echo "OK: MBP runs cachyos-lto with BORE, single kernel"
              touch $out
            '';

        # eval-no-overlay-rebuild-leak — GENERIC, forward-looking guard: NO global
        # overlay may REDEFINE an existing nixpkgs package, on any host, ever.
        # Overriding an existing package rebuilds it AND every dependent from
        # source (the libtpms -> tpm2-tss -> systemd -> whole-userland incident —
        # but the rule holds for any package). For every overlay each host applies
        # we force only the attr NAMES it produces (never their values, so it can
        # never error on broken/unfree attrs) and flag any name that ALREADY
        # exists in pristine nixpkgs (= an override). Adds-only overlays (e.g.
        # mesa-git, which introduces a NEW name) are fine. Genuinely-intentional
        # global overrides must be listed in `allowed` below, each with a reason.
        eval-no-overlay-rebuild-leak =
          let
            inherit (pkgs) lib;
            # Reviewed, intentional global package overrides — leaf/app packages
            # whose override rebuilds only themselves, NOT a foundational lib that
            # cascades into systemd/glibc/the whole system. A NEW name appearing
            # in the failure means someone added a global override: if it's a leaf
            # app, add it here; if it's a library with dependents, SCOPE it instead
            # (pkgs.X.override / services.*.package) so it can't silently rebuild
            # half the system. (openldap/vimPlugins have more dependents than the
            # apps — keep them here only while the override stays cache-cheap.)
            allowed = [
              "coolercontrol"
              "eden"
              "lmstudio"
              "lsfg-vk"
              "mullvad-vpn"
              "openldap"
              "streamcontroller"
              "tidal"
              "vimPlugins"
            ];
            # An overlay "overrides" a package when it returns an attr name that
            # already exists upstream AND changes its derivation. Attr names are
            # introspected without forcing values; drvPath is forced only for the
            # few real candidates, so metadata-only / no-op overlays don't false-
            # positive and broken/unfree attrs never error.
            drvOf =
              set: n:
              let
                r = builtins.tryEval set.${n}.drvPath;
              in
              if r.success then r.value else null;
            checkHost =
              host:
              let
                cfg = inputs.self.nixosConfigurations.${host};
                overlaid = cfg.pkgs;
                pristine = import overlaid.path { inherit (overlaid) system; };
                overlays = overlaid.overlays or cfg.config.nixpkgs.overlays;
                candidatesOf =
                  ov:
                  let
                    r = builtins.tryEval (builtins.attrNames (ov pristine pristine));
                  in
                  if r.success then builtins.filter (n: pristine ? ${n}) r.value else [ "<uninspectable-overlay>" ];
                candidates = lib.unique (lib.concatMap candidatesOf overlays);
                overridden = builtins.filter (
                  n:
                  n == "<uninspectable-overlay>"
                  || (
                    let
                      a = drvOf overlaid n;
                    in
                    a != null && a != drvOf pristine n
                  )
                ) candidates;
                violations = lib.subtractLists allowed overridden;
              in
              lib.optionalString (violations != [ ]) "\n  ${host}: ${lib.concatStringsSep " " violations}";
            report = lib.concatMapStrings checkHost (builtins.attrNames inputs.self.nixosConfigurations);
          in
          pkgs.runCommand "eval-no-overlay-rebuild-leak" { inherit report; } ''
            if [ -n "$report" ]; then
              echo "FAIL: un-allowlisted global overlay override(s):$report"
              echo "A global override rebuilds that package + every dependent from source"
              echo "(the libtpms -> tpm2-tss -> systemd -> whole-system incident). If it is a"
              echo "library with dependents, SCOPE it (pkgs.<p>.override / services.*.package);"
              echo "if it is an intentional leaf-app override, add the name to 'allowed' in"
              echo "parts/_build/tests.nix with a note."
              exit 1
            fi
            echo "OK: no un-allowlisted global package overrides on any host"
            touch $out
          '';

        # eval-no-overlay-rebuild-leak-test — keeps the guard honest + GENERIC: an
        # overlay overriding ANY existing package (here `hello`) MUST be caught,
        # while an adds-only overlay (a fresh name) MUST NOT be flagged.
        eval-no-overlay-rebuild-leak-test =
          let
            pristine = import inputs.self.nixosConfigurations.ryzen-9950x3d.pkgs.path { inherit system; };
            overriddenBy = ov: builtins.filter (n: pristine ? ${n}) (builtins.attrNames (ov pristine pristine));
            badOverlay = _final: prev: {
              hello = prev.hello.overrideAttrs (o: {
                pname = "${o.pname or "hello"}-leak";
              });
            };
            addOverlay = _final: prev: { my-brand-new-pkg = prev.hello; };
            caughtBad = overriddenBy badOverlay;
            flaggedAdd = overriddenBy addOverlay;
          in
          pkgs.runCommand "eval-no-overlay-rebuild-leak-test"
            {
              bad = builtins.concatStringsSep " " caughtBad;
              add = builtins.concatStringsSep " " flaggedAdd;
            }
            ''
              echo "override-overlay flagged: [$bad]   adds-only overlay flagged: [$add]"
              grep -qw hello <<< "$bad" \
                || { echo "FAIL: override of an existing package NOT caught — gate is vacuous"; exit 1; }
              [ -z "$add" ] \
                || { echo "FAIL: adds-only overlay flagged ($add) — false positive"; exit 1; }
              echo "OK: catches overrides of any existing package, ignores adds-only overlays"
              touch $out
            '';

        # eval-multiseat-collisions — the multiseat seat-disjointness guard, kept honest
        # by failure injection. Feeds the SAME pure detector the module asserts on
        # (parts/hardware/_multiseat-collisions.nix) a collision-free seat set (must pass)
        # and a deliberately-colliding one — shared CPU + shared GPU + shared user — which
        # MUST be caught, so the module's build-time assertions can never silently rot.
        eval-multiseat-collisions =
          let
            inherit (pkgs) lib;
            detect = import ../hardware/_multiseat-collisions.nix { inherit lib; };
            mkSeat = a: {
              isPrimary = a.isPrimary or false;
              seatId = a.seatId or "seat0";
              inherit (a) user;
              cpuset = a.cpuset or null;
              gpu.pciAddress = a.gpu;
              audioPciAddress = a.audio or null;
              usbController = a.usb or null;
              inputDevices = a.inputDevices or [ ];
            };
            good = {
              a = mkSeat {
                isPrimary = true;
                user = "user";
                cpuset = "0-7,16-23";
                gpu = "0000:03:00.0";
                inputDevices = [
                  {
                    vendorId = "046d";
                    productId = "c539";
                  }
                ];
              };
              b = mkSeat {
                seatId = "seat1";
                user = "seat1";
                cpuset = "8-15,24-31";
                gpu = "0000:05:00.0";
                audio = "0000:05:00.1";
                usb = "0000:7c:00.4";
                inputDevices = [
                  {
                    vendorId = "1532";
                    productId = "0084";
                  }
                ];
              };
            };
            # Inject four collisions at once: CPU 7 in both, same GPU, same user,
            # same input device (vendor:product).
            bad = {
              a = mkSeat {
                isPrimary = true;
                user = "user";
                cpuset = "0-7,16-23";
                gpu = "0000:03:00.0";
                inputDevices = [
                  {
                    vendorId = "046d";
                    productId = "c539";
                  }
                ];
              };
              b = mkSeat {
                seatId = "seat1";
                user = "user";
                cpuset = "7-15";
                gpu = "0000:03:00.0";
                inputDevices = [
                  {
                    vendorId = "046d";
                    productId = "c539";
                  }
                ];
              };
            };
          in
          pkgs.runCommand "eval-multiseat-collisions"
            {
              good = builtins.concatStringsSep " | " (detect good);
              bad = builtins.concatStringsSep " | " (detect bad);
            }
            ''
              echo "disjoint seats → [$good]"
              echo "colliding seats → [$bad]"
              [ -z "$good" ] || { echo "FAIL: disjoint seats wrongly flagged as colliding: $good"; exit 1; }
              grep -qi "CPU" <<< "$bad" || { echo "FAIL: shared CPU not caught"; exit 1; }
              grep -qi "device" <<< "$bad" || { echo "FAIL: shared GPU/device not caught"; exit 1; }
              grep -qi "user" <<< "$bad" || { echo "FAIL: shared login user not caught"; exit 1; }
              grep -qi "input device" <<< "$bad" || { echo "FAIL: shared input device not caught"; exit 1; }
              echo "OK: multiseat guard catches shared CPU/device/user/input and passes disjoint seats"
              touch $out
            '';
      };
    };
}
