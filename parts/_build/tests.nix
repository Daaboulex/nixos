# NixOS VM integration tests for myModules
# Run: nix build .#checks.x86_64-linux.<test-name>
# Run all: nix flake check (includes these alongside treefmt/git-hooks checks)
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # Every check binary, imported once (see checks/default.nix).
      checkBins = import ../_build/checks { inherit pkgs; };
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

        # eval-no-deprecations — fails if any host config sets a deprecated /
        # renamed nixpkgs option that originates in OUR flake source. Warnings
        # are filtered by source path: those attributed to nixpkgs (or any other
        # input) are dropped, so upstream-internal deprecations we cannot fix
        # never fire this gate, and it needs ZERO allowlist maintenance — it
        # only fires the day our own config uses a renamed option. Evaluates the
        # host configs (ryzen pulls VFIO IFD), so it runs in the local/ryzen
        # `nix flake check`, not the hosted-CI gates (like the other eval-*).
        eval-no-deprecations =
          let
            l = pkgs.lib;
            # unsafeDiscardStringContext: hasInfix builds a regex from selfPath,
            # and a regex pattern may not carry store-path string context. The
            # path VALUE is unchanged, so the match is identical.
            selfPath = builtins.unsafeDiscardStringContext (toString inputs.self);
            ownWarnings =
              host: l.filter (w: l.hasInfix selfPath w) inputs.self.nixosConfigurations.${host}.config.warnings;
            perHost = map (h: {
              host = h;
              ws = ownWarnings h;
            }) (builtins.attrNames inputs.self.nixosConfigurations);
            offenders = l.filter (x: x.ws != [ ]) perHost;
            report = l.concatMapStringsSep "\n" (
              x: "  ${x.host}:\n" + l.concatMapStringsSep "\n" (w: "    - ${w}") x.ws
            ) offenders;
          in
          if offenders == [ ] then
            pkgs.runCommand "eval-no-deprecations" { }
              "echo 'OK: no config-origin deprecation warnings'; touch $out"
          else
            throw "eval-no-deprecations — your config sets deprecated/renamed options:\n${report}\n  Fix each at the cited file. Upstream-origin warnings are excluded automatically.";

        # Proves the source-origin discriminator is non-vacuous: a config-origin
        # warning is caught, an upstream (nixpkgs) one is ignored. Pure (CI-safe).
        eval-no-deprecations-test =
          let
            l = pkgs.lib;
            self = "/nix/store/aaaa-source";
            ours = "The option `x' defined in `${self}/parts/x.nix' has been renamed to `y'.";
            upstream = "The option `z' defined in `/nix/store/bbbb-nixpkgs-source/flake.nix' has been renamed.";
            caught = l.filter (w: l.hasInfix self w) [
              ours
              upstream
            ];
          in
          if caught == [ ours ] then
            pkgs.runCommand "eval-no-deprecations-test" { }
              "echo 'OK: origin filter catches ours, ignores upstream'; touch $out"
          else
            throw "eval-no-deprecations-test: origin filter wrong, caught=${builtins.toJSON caught}";

        # check-placement hook — asserts the hook fires on a synthetic
        # violation (scope mismatch) AND passes on a compliant file. Keeps
        # the hook from becoming vacuously green when the tree is clean.
        check-placement-test =
          pkgs.runCommand "check-placement-test"
            {
              nativeBuildInputs = [ checkBins."check-placement" ];
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
              nativeBuildInputs = [ checkBins."check-dangling-refs" ];
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

        # check-session-vars — live gate: every home module routes session vars
        # through myLib.mkSessionVars (both home + systemd user env), never a raw
        # home.sessionVariables/systemd.user.sessionVariables assignment (hm #5542).
        check-session-vars =
          pkgs.runCommand "check-session-vars"
            {
              nativeBuildInputs = [ checkBins."check-session-vars" ];
              src = ../../home/modules;
            }
            ''
              set -euo pipefail
              mkdir -p home
              cp -r "$src" home/modules
              if ! check-session-vars --all; then
                echo "check-session-vars: a home module sets session vars directly; use myLib.mkSessionVars or mark '# session-vars-ok'."
                exit 1
              fi
              echo "OK: all home-module session vars go through myLib.mkSessionVars"
              touch "$out"
            '';

        # check-session-vars hook — asserts the checker FIRES on a raw assignment
        # AND passes the helper form. Keeps the gate non-vacuous.
        check-session-vars-test =
          pkgs.runCommand "check-session-vars-test"
            {
              nativeBuildInputs = [ checkBins."check-session-vars" ];
              violation = ./tests/fixtures/session-vars-violation.nix;
              ok = ./tests/fixtures/session-vars-ok.nix;
            }
            ''
              set -euo pipefail
              if check-session-vars "$violation"; then
                echo "FAIL: did not catch a raw home.sessionVariables assignment"
                exit 1
              fi
              if ! check-session-vars "$ok"; then
                echo "FAIL: rejected the myLib.mkSessionVars form"
                exit 1
              fi
              echo "OK: check-session-vars fires on raw assignment, passes the helper form"
              touch "$out"
            '';

        # check-dangling-refs hook — asserts the checker FIRES on an unguarded
        # reference AND PASSES the guarded form. Keeps the gate non-vacuous.
        check-dangling-refs-test =
          pkgs.runCommand "check-dangling-refs-test"
            {
              nativeBuildInputs = [ checkBins."check-dangling-refs" ];
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
              nativeBuildInputs = [ checkBins."check-no-foreign-config" ];
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
              nativeBuildInputs = [ checkBins."check-no-foreign-config" ];
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

        # check-portmaster-chain-ownership — live gate: Portmaster chain
        # surgery happens through lib/mkPortmasterChainKeeper.nix only, so
        # every such rule survives Portmaster's pause/resume lifecycle.
        check-portmaster-chain-ownership =
          pkgs.runCommand "check-portmaster-chain-ownership"
            {
              nativeBuildInputs = [ checkBins."check-portmaster-chain-ownership" ];
              partsSrc = ../../parts;
              homeSrc = ../../home/modules;
              libSrc = ../../lib;
            }
            ''
              set -euo pipefail
              mkdir -p root/home
              cp -r "$partsSrc" root/parts
              cp -r "$homeSrc" root/home/modules
              cp -r "$libSrc" root/lib
              cd root
              if ! check-portmaster-chain-ownership --all; then
                echo "check-portmaster-chain-ownership: direct ip(6)tables surgery on a PORTMASTER- chain outside lib/mkPortmasterChainKeeper.nix."
                exit 1
              fi
              echo "OK: Portmaster chain surgery only via mkPortmasterChainKeeper"
              touch "$out"
            '';

        # check-portmaster-chain-ownership hook — asserts it FIRES on inline
        # chain surgery AND PASSES chain names as keeper rules data. Keeps
        # the gate non-vacuous.
        check-portmaster-chain-ownership-test =
          pkgs.runCommand "check-portmaster-chain-ownership-test"
            {
              nativeBuildInputs = [ checkBins."check-portmaster-chain-ownership" ];
              violation = ./tests/fixtures/portmaster-chain-violation.nix;
              ok = ./tests/fixtures/portmaster-chain-ok.nix;
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              mkdir -p parts/security

              install -m 0644 "$violation" parts/security/compat.nix
              if diag=$(check-portmaster-chain-ownership parts/security/compat.nix 2>&1); then
                echo "FAIL: violation fixture passed; expected exit 1."
                echo "$diag"
                exit 1
              fi
              grep -q 'mkPortmasterChainKeeper' <<< "$diag" \
                || { echo "FAIL: diagnostic missing the sanctioned helper."; echo "$diag"; exit 1; }

              install -m 0644 "$ok" parts/security/compat.nix
              if ! check-portmaster-chain-ownership parts/security/compat.nix; then
                echo "FAIL: rules-as-data fixture rejected; expected pass."
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
              nativeBuildInputs = [ checkBins."check-placement" ];
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
              nativeBuildInputs = [ checkBins."check-dedup" ];
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
              nativeBuildInputs = [ checkBins."check-dedup" ];
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
              nativeBuildInputs = [ checkBins."nixos-exhaustiveness" ];
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

        # deploy-readiness — live gate: every bare-metal host carries the
        # install contract (disko.nix, inert at runtime, wired, by-path).
        # The site-escrow half is enforced at runtime by nrb --install.
        deploy-readiness =
          pkgs.runCommand "deploy-readiness"
            {
              nativeBuildInputs = [ checkBins."deploy-readiness" ];
              partsSrc = ../../parts;
            }
            ''
              set -euo pipefail
              mkdir root
              cp -r "$partsSrc" root/parts
              cd root
              if ! deploy-readiness --all; then
                echo "deploy-readiness: a bare-metal host is missing its install contract."
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
              nativeBuildInputs = [ checkBins."check-specialisation-placement" ];
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
              nativeBuildInputs = [ checkBins."check-specialisation-placement" ];
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
              nativeBuildInputs = [ checkBins."check-helper-naming" ];
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
              nativeBuildInputs = [ checkBins."check-helper-naming" ];
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
              nativeBuildInputs = [ checkBins."check-no-narration-comments" ];
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
              nativeBuildInputs = [ checkBins."check-no-narration-comments" ];
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"
              printf '{\n  # moved to the HM module\n  x = 1;\n}\n' > bad.nix # narration-ok: gate self-test fixture
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
              nativeBuildInputs = [ checkBins."nixos-exhaustiveness" ];
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
              nativeBuildInputs = [ checkBins."check-no-with-lib" ];
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
          pkgs.runCommand "check-no-with-lib-test" { nativeBuildInputs = [ checkBins."check-no-with-lib" ]; }
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
              nativeBuildInputs = [ checkBins."check-no-dated-comments" ];
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
            { nativeBuildInputs = [ checkBins."check-no-dated-comments" ]; }
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
              nativeBuildInputs = [ checkBins."check-mkforce-comment" ];
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
          pkgs.runCommand "check-mkforce-comment-test"
            { nativeBuildInputs = [ checkBins."check-mkforce-comment" ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf '{ lib, ... }:\n{\n  services.x.enable = lib.mkForce false;\n}\n' > bad.nix
              if check-mkforce-comment bad.nix; then echo "FAIL: bare mkForce passed"; exit 1; fi
              printf '{ lib, ... }:\n{\n  # Why: upstream forces it on; we need it off here.\n  services.x.enable = lib.mkForce false;\n}\n' > good.nix
              if ! check-mkforce-comment good.nix; then echo "FAIL: justified mkForce rejected"; exit 1; fi
              touch "$out"
            '';

        # A temporary overlay fix must not outlive its reason: evaluate every
        # parts/overlays/_fixes dropWhen against a probe pkgs WITHOUT the
        # fixes; any that fires names its file for deletion (or for updating
        # its observed version after re-verifying upstream).
        overlay-fixes-current =
          let
            probePkgs = import inputs.nixpkgs {
              localSystem.system = system;
              config.allowUnfree = true;
              overlays = [ inputs.self.overlays.probe ];
            };
            fixesDir = ../overlays/_fixes;
            fixes =
              map
                (
                  name:
                  let
                    v = import (fixesDir + "/${name}");
                  in
                  assert pkgs.lib.assertMsg (
                    v ? dropWhen && v ? overlay
                  ) "overlay fix ${name} must declare dropWhen and overlay";
                  v // { inherit name; }
                )
                (builtins.filter (n: pkgs.lib.hasSuffix ".nix" n) (builtins.attrNames (builtins.readDir fixesDir)));
            expired = pkgs.lib.filter (f: f.dropWhen probePkgs) fixes;
            names = pkgs.lib.concatMapStringsSep ", " (f: f.name) expired;
          in
          if expired == [ ] then
            pkgs.runCommand "overlay-fixes-current" { }
              "echo 'OK: every overlay fix is still needed'; touch $out"
          else
            throw "expired overlay fix(es): ${names} — upstream may have healed; re-verify, then delete parts/overlays/_fixes/<file> or update its observed version.";

        # Fixture-repo self-test: `nix flake check` cannot see the gitignored
        # repos/, so the live enforcement is the pre-commit hook; this proves
        # the verdict logic fires (pass in-sync, fail pin-behind, notice-only
        # when the workbench lags the pin).
        check-pin-behind-checkout-test =
          pkgs.runCommand "check-pin-behind-checkout-test"
            {
              nativeBuildInputs = [
                checkBins."check-pin-behind-checkout"
                pkgs.git
              ];
            }
            ''
              set -euo pipefail
              export HOME=$TMPDIR
              g() { git -c user.email=t@t -c user.name=t "$@"; }
              root=$TMPDIR/fixture
              mkdir -p "$root/repos/foo-nix"
              cd "$root/repos/foo-nix"
              g init -q -b main
              echo a > f && g add f && g commit -qm c1
              rev1=$(g rev-parse HEAD)
              cd "$root"
              printf '{"nodes":{"root":{"inputs":{"foo":"foo"}},"foo":{"locked":{"type":"github","owner":"Daaboulex","repo":"foo-nix","rev":"%s"}}},"version":7}' "$rev1" > flake.lock

              # in-sync pin: must pass
              check-pin-behind-checkout "$root"

              # workbench gains a commit the pin lacks: must fail
              cd "$root/repos/foo-nix"
              echo b >> f && g commit -qam c2
              cd "$root"
              if check-pin-behind-checkout "$root"; then
                echo "FAIL: pin behind workbench not detected"; exit 1
              fi

              # pin unknown to the workbench (stale checkout): notice only, must pass
              printf '{"nodes":{"root":{"inputs":{"foo":"foo"}},"foo":{"locked":{"type":"github","owner":"Daaboulex","repo":"foo-nix","rev":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"}}},"version":7}' > flake.lock
              check-pin-behind-checkout "$root"

              # no repos/ dir (CI shape): must pass
              mkdir -p "$TMPDIR/bare" && cp flake.lock "$TMPDIR/bare/"
              check-pin-behind-checkout "$TMPDIR/bare"
              touch "$out"
            '';

        check-assertion-format =
          pkgs.runCommand "check-assertion-format"
            {
              nativeBuildInputs = [ checkBins."check-assertion-format" ];
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
            { nativeBuildInputs = [ checkBins."check-assertion-format" ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf '{\n  assertions = [\n    {\n      assertion = false;\n      message = "something broke";\n    }\n  ];\n}\n' > bad.nix
              if check-assertion-format bad.nix; then echo "FAIL: bad assertion message passed"; exit 1; fi
              printf '{\n  assertions = [\n    {\n      assertion = false;\n      message = "myModules.x.y: must be set";\n    }\n  ];\n}\n' > good.nix
              if ! check-assertion-format good.nix; then echo "FAIL: good assertion rejected"; exit 1; fi
              touch "$out"
            '';

        # check-commit-message hook -- asserts the gate FIRES on a malformed
        # subject / missing trailer and passes conforming + git-generated
        # messages.
        check-commit-message-test =
          pkgs.runCommand "check-commit-message-test"
            { nativeBuildInputs = [ checkBins."check-commit-message" ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"
              printf 'fix(vpn): mark every packet\n\nbody.\n\nEval: tunnel-live-smoke=pass\n' > good
              check-commit-message good
              printf 'chore(flake): land the bump\n\nEval: n/a\n' > good2
              check-commit-message good2
              printf 'Merge branch main\n' > merge
              check-commit-message merge
              printf 'fix: unscoped subject\n\nEval: n/a\n' > bad1
              if check-commit-message bad1; then echo "FAIL: unscoped subject passed"; exit 1; fi
              printf 'wip(vpn): unknown type\n\nEval: n/a\n' > bad2
              if check-commit-message bad2; then echo "FAIL: unknown type passed"; exit 1; fi
              printf 'fix(vpn): trailer missing\n\njust a body\n' > bad3
              if check-commit-message bad3; then echo "FAIL: missing Eval trailer passed"; exit 1; fi
              touch "$out"
            '';

        check-module-docstring =
          pkgs.runCommand "check-module-docstring"
            {
              nativeBuildInputs = [ checkBins."check-module-docstring" ];
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
            { nativeBuildInputs = [ checkBins."check-module-docstring" ]; }
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

        check-module-class =
          pkgs.runCommand "check-module-class"
            {
              nativeBuildInputs = [ checkBins."check-module-class" ];
              partsSrc = ../../parts;
            }
            ''
              set -euo pipefail
              mkdir -p root && cp -r "$partsSrc" root/parts
              cd root
              if ! check-module-class --all; then echo "check-module-class: a module export is missing _class"; exit 1; fi
              echo "OK: every parts module export declares _class = nixos"; touch "$out"
            '';
        check-module-class-test =
          pkgs.runCommand "check-module-class-test"
            { nativeBuildInputs = [ checkBins."check-module-class" ]; }
            ''
              set -euo pipefail
              work=$(mktemp -d); cd "$work"; mkdir -p parts/widgets
              # module export WITHOUT _class -> must fail.
              printf '%s\n' '{ inputs, ... }: {' '  flake.modules.nixos.foo = { lib, ... }: { options = { }; };' '}' > parts/widgets/foo.nix
              if check-module-class parts/widgets/foo.nix; then echo "FAIL: class-less module export passed"; exit 1; fi
              # module export WITH _class -> must pass.
              printf '%s\n' '{ inputs, ... }: {' '  flake.modules.nixos.bar = { lib, ... }: { _class = "nixos"; options = { }; };' '}' > parts/widgets/bar.nix
              if ! check-module-class parts/widgets/bar.nix; then echo "FAIL: classed module export rejected"; exit 1; fi
              touch "$out"
            '';

        check-secrets-leak =
          pkgs.runCommand "check-secrets-leak"
            {
              nativeBuildInputs = [ checkBins."check-secrets-leak" ];
              src = ../../.;
            }
            ''
              set -euo pipefail
              cp -r "$src" root && cd root
              if ! check-secrets-leak --all; then echo "check-secrets-leak: forbidden path present"; exit 1; fi
              echo "OK: no secret material in the tree"; touch "$out"
            '';
        check-secrets-leak-test =
          pkgs.runCommand "check-secrets-leak-test"
            { nativeBuildInputs = [ checkBins."check-secrets-leak" ]; }
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
              nativeBuildInputs = [ checkBins."check-no-cross-tree-import" ];
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
            { nativeBuildInputs = [ checkBins."check-no-cross-tree-import" ]; }
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
            echo "pipewire.enable = ${toString testCfg.config.myModules.hardware.pipewire.enable}"
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

            # Nix daemon + settings. nix-daemon is socket-activated, so the .service
            # is inactive until first use -- wait on the socket (the boot-active unit).
            machine.wait_for_unit("nix-daemon.socket")
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
            # Test-only: newer OpenSSH enables PerSourcePenalties by default,
            # which penalizes ssh-keyscan's connect-grab-key-disconnect (no
            # auth) as abuse and drops the probe -- so the host-key assertion
            # below reads empty. Off here isolates the test to what it checks
            # (key relocation + sshd serving it); real hosts keep the default.
            services.openssh.settings.PerSourcePenalties = "no";
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

            # Host-key migration: a pre-existing /etc/ssh identity must be
            # COPIED to /var/lib/ssh by activation (copy-if-absent) -- never
            # regenerated, or the machine loses its identity (agenix,
            # registry pins, remote-builder trust).
            machine.succeed("systemctl stop sshd.service sshd.socket 2>/dev/null || systemctl stop sshd.service")
            machine.succeed("ssh-keygen -t ed25519 -N \"\" -f /tmp/planted -C planted 1>&2")
            machine.succeed("cp /tmp/planted /etc/ssh/ssh_host_ed25519_key && cp /tmp/planted.pub /etc/ssh/ssh_host_ed25519_key.pub")
            machine.succeed("rm -f /var/lib/ssh/ssh_host_ed25519_key /var/lib/ssh/ssh_host_ed25519_key.pub")
            machine.succeed("/run/current-system/activate 1>&2")
            machine.succeed("cmp /var/lib/ssh/ssh_host_ed25519_key /tmp/planted")
            machine.succeed("systemctl start sshd.service")
            machine.wait_for_unit("sshd.service")
            machine.wait_for_open_port(22)
            # OpenSSH 10.3's ssh-keyscan prints its "# host SSH-2.0-..." banner
            # comment to STDOUT (it used to go to stderr), so 2>/dev/null no
            # longer hides it -- grep -v '^#' drops it and leaves the key line,
            # whose $3 is the served ed25519 key to compare against planted.pub.
            machine.succeed(
                "[ \"$(ssh-keyscan -t ed25519 localhost 2>/dev/null | grep -v '^#' | awk '{print $3}')\" = \"$(awk '{print $2}' /tmp/planted.pub)\" ]"
            )
          '';
        };

        # vm-btrbk-restore — the restore path proven end to end on real
        # btrfs: replicate, verify (positive AND garbled-negative), destroy
        # the live data, restore through both the local-snapshot fast path
        # and the target send/receive path (via a pty -- the tool refuses
        # non-TTY by design), and confirm the never-delete guarantee. A
        # restore tool is untested until the day it is needed unless a
        # harness needs it first.
        vm-btrbk-restore = pkgs.testers.nixosTest {
          name = "btrbk-restore";
          nodes.machine = {
            imports = [ inputs.self.modules.nixos.storage-btrbk ];
            virtualisation.memorySize = 1024;
            virtualisation.graphics = false;
            virtualisation.emptyDiskImages = [
              512
              512
            ];
            # The test builds its own btrfs world (mkfs.btrfs); the btrbk module
            # uses pinned internal paths, so btrfs-progs is not otherwise on the
            # VM's interactive PATH (the newer nixpkgs stopped pulling it in).
            environment.systemPackages = [ pkgs.btrfs-progs ];
            myModules.storage.btrbk = {
              enable = true;
              sourcePath = "/mnt/src";
              targetPath = "/mnt/tgt";
              subvolumes = [ "@data" ];
            };
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Build the btrfs world the module expects (the tmpfiles-made
            # dirs from boot are shadowed once we mount, so recreate them).
            machine.succeed("mkfs.btrfs -f /dev/vdb 1>&2 && mkfs.btrfs -f /dev/vdc 1>&2")
            machine.succeed("mkdir -p /mnt/src /mnt/tgt")
            # max_inline=0: keep the tiny test files out of inline metadata so
            # they occupy real data extents. Otherwise `btrfs filesystem du`
            # reports 0 bytes for the target snapshot and the restore tool's
            # fail-closed size guard (need > 0) refuses -- an artifact of the
            # unrealistically small test payload, not a tool fault.
            machine.succeed(
                "mount -o max_inline=0 /dev/vdb /mnt/src && mount -o max_inline=0 /dev/vdc /mnt/tgt"
            )
            machine.succeed("btrfs subvolume create /mnt/src/@data 1>&2")
            machine.succeed("mkdir -p /mnt/src/.snapshots/btrbk /mnt/tgt/@data")
            machine.succeed("echo precious > /mnt/src/@data/file")

            # First replication: source snapshot + full send to the target.
            machine.succeed("systemctl start btrbk-default.service")
            snap = machine.succeed("ls /mnt/tgt/@data/").strip()
            assert snap.startswith("@data."), f"no received snapshot on target: {snap}"
            stamp = snap.split(".", 1)[1]

            # verify: a complete received snapshot passes; a garbled
            # (writable, never-received) one must FAIL.
            machine.succeed(f"btrbk-restore verify @data {stamp} 1>&2")
            machine.succeed("mkdir /mnt/tgt/@data/@data.20200101T0000")
            machine.fail("btrbk-restore verify @data 20200101T0000 1>&2")
            machine.succeed("rmdir /mnt/tgt/@data/@data.20200101T0000")

            # Restore 1: local-snapshot fast path, interactively via a pty.
            machine.succeed("echo corrupted > /mnt/src/@data/file")
            machine.succeed(
                f"printf 'restore\\n' | script -qec 'btrbk-restore restore @data {stamp}' /dev/null 1>&2"
            )
            machine.succeed("grep -qx precious /mnt/src/@data/file")
            # Never-delete guarantee: the replaced state is KEPT.
            machine.succeed("grep -qx corrupted /mnt/src/@data.pre-restore-*/file")

            # Restore 2: the disaster path -- local snapshots gone, restore
            # arrives from the target via send/receive.
            machine.succeed(f"btrfs subvolume delete /mnt/src/.snapshots/btrbk/@data.{stamp} 1>&2")
            machine.succeed("echo corrupted-again > /mnt/src/@data/file")
            machine.succeed(
                f"printf 'restore\\n' | script -qec 'btrbk-restore restore @data {stamp}' /dev/null 1>&2"
            )
            machine.succeed("grep -qx precious /mnt/src/@data/file")
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

        # vm-split-tunnel — the netmap must carry EVERY packet of an aliased
        # flow on a LAN that collides with the routed subnet. The regression
        # this guards: an skb fwmark set in the nat-hook chain marks only a
        # flow's first packet, so packets 2+ reroute via the main table and
        # egress the colliding LAN — handshakes complete, all data dies. The
        # test drives the module's real artifacts (dataPlane), completes a
        # multi-packet HTTP exchange through the alias, and holds a hard
        # zero-leak counter plus the no-ARP tell on the colliding interface.
        vm-split-tunnel = pkgs.testers.nixosTest {
          name = "split-tunnel";
          nodes = {
            client = {
              imports = [ inputs.self.modules.nixos.services-split-tunnel ];
              # Synthetic site fixture — the module reads only network.vpn.
              _module.args.site = {
                network.vpn = {
                  name = "Test VPN";
                  server = "vpn.test.invalid";
                  routedSubnets = [ "192.168.83.0/24" ];
                  dnsServer = "192.168.83.7";
                  dnsDomains = [ "corp.test" ];
                };
              };
              virtualisation.vlans = [
                1
                2
              ];
              virtualisation.memorySize = 512;
              virtualisation.graphics = false;
              environment.systemPackages = [
                pkgs.curl
                pkgs.nftables
              ];
              # The colliding LAN: eth1 carries an address INSIDE the routed
              # subnet — the exact topology the alias design exists for.
              networking.interfaces.eth1.ipv4.addresses = [
                {
                  address = "192.168.83.90";
                  prefixLength = 24;
                }
              ];
              # eth2 stands in for the tunnel interface; the address mirrors
              # the VPN-assigned pool source.
              networking.interfaces.eth2.ipv4.addresses = [
                {
                  address = "172.16.9.4";
                  prefixLength = 24;
                }
              ];
              # Replies arrive on eth2 with a source inside eth1's subnet;
              # mirrors the loose-rpfilter pin real hosts carry in hardening.
              networking.firewall.checkReversePath = false;
              boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = 2;
            };
            office = {
              virtualisation.vlans = [ 2 ];
              virtualisation.memorySize = 512;
              virtualisation.graphics = false;
              networking.firewall.enable = false;
              networking.interfaces.eth1.ipv4.addresses = [
                {
                  address = "192.168.83.7";
                  prefixLength = 24;
                }
              ];
              # Return path to the pool source, on-link over the same segment.
              networking.interfaces.eth1.ipv4.routes = [
                {
                  address = "172.16.9.0";
                  prefixLength = 24;
                }
              ];
              systemd.services.testsrv = {
                wantedBy = [ "multi-user.target" ];
                script = ''
                  echo tunnel-proof > /tmp/proof
                  exec ${pkgs.python3}/bin/python3 -m http.server 8000 --directory /tmp --bind 0.0.0.0
                '';
              };
            };
          };
          testScript =
            { nodes, ... }:
            let
              stCfg = nodes.client.config.myModules.services.splitTunnel;
              dp = stCfg.dataPlane;
              # The alias prefix comes from the option; the preserved third
              # octet is the documented mapping -- the contract under test,
              # stated here independently of the implementation.
              officeAlias = "${stCfg.aliasNet}.83.7";
            in
            ''
              start_all()
              client.wait_for_unit("multi-user.target")
              office.wait_for_unit("testsrv.service")
              office.wait_for_open_port(8000)

              # Alias space is dark until vpn-up wires it.
              client.fail("curl -s --max-time 3 http://${officeAlias}:8000/proof")

              client.succeed("CONNECTION_ID='Test VPN' ${dp.lifecycle} eth2 vpn-up 1>&2")

              # The alias /24 route in the MAIN table is NM-profile-owned in
              # production (routeAttrs); the lifecycle script deliberately
              # does not manage it. Model NM's route here.
              client.succeed("ip route replace ${stCfg.aliasNet}.83.0/24 dev eth2 metric 50")

              # Netmap loaded, marked traffic pinned to the alias table, and
              # the real-subnet route WITHHELD (a local address occupies it).
              client.succeed("nft list table ip ${dp.tableName} 1>&2")
              client.succeed("ip rule | grep -q 'fwmark ${dp.fwmark} lookup ${dp.rtable}'")
              client.succeed("ip route show table ${dp.rtable} | grep -q '192.168.83.0/24 dev eth2'")
              client.fail("ip route show | grep -q '192.168.83.0/24 dev eth2'")

              # Hard leak counter: anything toward the office's REAL address
              # leaving the colliding interface is the regression.
              client.succeed("nft add table ip leakcheck")
              client.succeed(
                  "nft add chain ip leakcheck out '{ type filter hook output priority 150 ; policy accept ; }'"
              )
              client.succeed("nft add rule ip leakcheck out oifname eth1 ip daddr 192.168.83.7 counter")

              # Multi-packet exchange through the alias: handshake, request,
              # response — every packet past the first is the class under test.
              client.succeed("curl -s --max-time 10 http://${officeAlias}:8000/proof | grep -qx tunnel-proof")

              client.succeed("nft list chain ip leakcheck out | grep -q 'counter packets 0 bytes 0'")
              # The colliding interface never even ARPed the office's real IP.
              client.fail("ip neigh show dev eth1 | grep -q 192.168.83.7")

              # Teardown removes everything it added.
              client.succeed("CONNECTION_ID='Test VPN' ${dp.lifecycle} eth2 vpn-down 1>&2")
              client.fail("nft list table ip ${dp.tableName} 1>&2")
              client.succeed("[ -z \"$(ip route show table ${dp.rtable})\" ]")
              client.fail("ip rule | grep -q 'lookup ${dp.rtable}'")
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
            # PipeWire is a per-user, socket-activated service; with no login session
            # the user@ instance never starts. Linger brings it up at boot so the
            # user's pipewire.socket is active in this headless VM.
            users.users.user.linger = true;
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            # PipeWire user socket is up (socket-activated; the daemon starts on demand)
            machine.wait_for_unit("pipewire.socket", "user")
            # LADSPA plugins are wired via LADSPA_PATH on the pipewire user service
            # (extraLadspaPackages -> services.pipewire.extraLadspaPackages -> env),
            # NOT a pipewire.conf.d entry. Catches the LADSPA_PATH wiring regression.
            machine.succeed("systemctl --user -M user@ show pipewire.service -p Environment | grep -q LADSPA_PATH")
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

        # myLib.mkSessionVars — contract: the same attrset lands on BOTH
        # home.sessionVariables and systemd.user.sessionVariables (hm #5542).
        eval-mylib-mkSessionVars =
          let
            out = inputs.self.lib.mkSessionVars { FOO = "bar"; };
            ok =
              (out.home.sessionVariables.FOO or null) == "bar"
              && (out.systemd.user.sessionVariables.FOO or null) == "bar";
          in
          pkgs.runCommand "eval-mylib-mkSessionVars" { } (
            if ok then
              ''
                echo "OK: mkSessionVars sets the var on both home + systemd.user"
                touch $out
              ''
            else
              ''
                echo "FAIL: mkSessionVars did not set the var on both targets"
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

        # myLib.kernelModuleGuards — contract: each assertion branch fires on
        # its illegal state, a clean config passes, and a late-only module in
        # the initrd warns. The heaviest-logic helper; no host builds a
        # conflicting state by design, so this is where its branches are proven.
        eval-mylib-kernelModuleGuards =
          let
            inherit (pkgs) lib;
            guard = cfg: inputs.self.lib.kernelModuleGuards { config = cfg; };
            fires = cfg: builtins.any (a: !a.assertion) (guard cfg).assertions;
            warns = cfg: (guard cfg).warnings != [ ];
            # a blacklisted module also in the load set still loads
            loadBlacklist = fires {
              boot.kernelModules = [ "k10temp" ];
              boot.blacklistedKernelModules = [ "k10temp" ];
            };
            # zenpower + k10temp bind the same hardware
            mutualExcl = fires {
              boot.kernelModules = [
                "zenpower"
                "k10temp"
              ];
            };
            # nvidia in the initrd while passthrough is requested
            nvDirty = fires {
              myModules.hardware.gpuNvidia.passthrough.enable = true;
              boot.initrd.kernelModules = [ "nvidia" ];
            };
            # no conflict: amdgpu loaded, nouveau blacklisted
            clean =
              !(fires {
                boot.kernelModules = [ "amdgpu" ];
                boot.blacklistedKernelModules = [ "nouveau" ];
              });
            # a late-only sensor driver placed in the initrd only warns
            lateWarn = warns {
              boot.initrd.kernelModules = [ "zenpower" ];
            };
            pass = loadBlacklist && mutualExcl && nvDirty && clean && lateWarn;
          in
          pkgs.runCommand "eval-mylib-kernelModuleGuards" { } (
            if pass then
              ''
                echo "OK: kernelModuleGuards fires on load+blacklist, mutually-exclusive,"
                echo "    and dirty nvidia-passthrough; clean config passes; late-in-initrd warns"
                touch $out
              ''
            else
              ''
                echo "FAIL: kernelModuleGuards branch coverage incomplete:"
                echo "  loadBlacklist=${lib.boolToString loadBlacklist} mutualExcl=${lib.boolToString mutualExcl} nvDirty=${lib.boolToString nvDirty}"
                echo "  clean=${lib.boolToString clean} lateWarn=${lib.boolToString lateWarn}"
                exit 1
              ''
          );

        # myLib.mkSpecialisations — contract: every .nix in a specialisations/
        # dir becomes specialisation.<name>.configuration; default.nix and
        # _-prefixed fragments are skipped; each value carries configuration.imports.
        # Run against ryzen's real dir (it has _common-vfio.nix to prove the skip).
        eval-mylib-specialisations =
          let
            inherit (pkgs) lib;
            specs = inputs.self.lib.mkSpecialisations {
              dir = ../hosts/ryzen-9950x3d/specialisations;
            };
            names = builtins.attrNames specs;
            nonEmpty = names != [ ];
            skipsUnderscore = !(builtins.any (lib.hasPrefix "_") names);
            skipsDefault = !(builtins.elem "default" names);
            shape = builtins.all (n: specs.${n} ? configuration.imports) names;
            pass = nonEmpty && skipsUnderscore && skipsDefault && shape;
          in
          pkgs.runCommand "eval-mylib-specialisations" { } (
            if pass then
              ''
                echo "OK: mkSpecialisations wired ${toString (builtins.length names)} spec(s),"
                echo "    skipped _-prefixed fragments + default.nix, each with configuration.imports"
                touch $out
              ''
            else
              ''
                echo "FAIL: mkSpecialisations contract: nonEmpty=${lib.boolToString nonEmpty} skipsUnderscore=${lib.boolToString skipsUnderscore} skipsDefault=${lib.boolToString skipsDefault} shape=${lib.boolToString shape}"
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

        # eval-etc-overlay-guard — the overlay safety contract must FIRE:
        # force-enabling the overlay without the declarative-password
        # prerequisite has to trip the etcOverlay assertion. Pins the guard
        # that keeps the /etc-overlay login-lockout class unbuildable.
        eval-etc-overlay-guard =
          let
            forced =
              (inputs.self.nixosConfigurations.macbook-pro-9-2.extendModules {
                modules = [
                  (
                    { lib, ... }:
                    {
                      myModules.boot.etcOverlay.enable = lib.mkForce true;
                    }
                  )
                ];
              }).config;
            failed = builtins.filter (a: !a.assertion) forced.assertions;
            guardFired = builtins.any (a: pkgs.lib.hasInfix "myModules.boot.etcOverlay" a.message) failed;
          in
          pkgs.runCommand "eval-etc-overlay-guard" { guardFired = builtins.toJSON guardFired; } ''
            echo "guard fired = $guardFired"
            [[ "$guardFired" == "true" ]] || {
              echo "FAIL: etcOverlay force-enabled without prerequisites did not trip its assertion"
              exit 1
            }
            touch $out
          '';

        # eval-users-password-guard — passwordFromSite without the
        # host-declared agenix secret must trip the users assertion.
        eval-users-password-guard =
          let
            forced =
              (inputs.self.nixosConfigurations.macbook-pro-9-2.extendModules {
                modules = [
                  (
                    { lib, ... }:
                    {
                      myModules.users.passwordFromSite = lib.mkForce true;
                    }
                  )
                ];
              }).config;
            failed = builtins.filter (a: !a.assertion) forced.assertions;
            guardFired = builtins.any (a: pkgs.lib.hasInfix "myModules.users" a.message) failed;
          in
          pkgs.runCommand "eval-users-password-guard" { guardFired = builtins.toJSON guardFired; } ''
            echo "guard fired = $guardFired"
            [[ "$guardFired" == "true" ]] || {
              echo "FAIL: passwordFromSite without the declared secret did not trip its assertion"
              exit 1
            }
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
            hasBpflandPrimaryDomain = pkgs.lib.elem "-m" cfg.services.scx.extraArgs;
          in
          pkgs.runCommand "eval-scx-scheduler"
            {
              actual = cfg.services.scx.scheduler;
              flags = toString cfg.services.scx.extraArgs;
            }
            ''
              [[ "$actual" == "scx_lavd" ]] \
                || { echo "FAIL: scx scheduler is '$actual', expected scx_lavd"; exit 1; }
              ${pkgs.lib.optionalString hasBpflandPrimaryDomain ''
                echo "FAIL: scx_lavd was given bpfland's -m flag (flags: $flags) -- lavd has no -m and fails to attach"
                exit 1
              ''}
              echo "OK: scx_lavd active with lavd-valid flags ($flags)"
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
              # Boot-time IP protection needs the tunnel up by default -- via the kill switch
              # (lockdownMode) OR auto-connect (autoConnect). lockdownMode is deliberately OFF
              # so the daemon can be stopped at runtime for clearnet / captive portals (a kill
              # switch would block all traffic then); autoConnect=true is the standing guarantee.
              # Fail only if BOTH are off -- then the VPN is not active by default at boot.
              [[ "$lockdown" == "true" || "$autoConn" == "true" ]] \
                || { echo "FAIL: neither lockdownMode nor autoConnect enabled -- VPN not active at boot, real IP exposed"; exit 1; }
              echo "OK: Mullvad active by default at boot (autoConnect=$autoConn, lockdownMode=$lockdown)"
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
              [[ "$mode" == "frequency" ]] || { echo "FAIL: x3dVcache mode is '$mode', expected 'frequency' (idle = high-clock CCD; gamemode flips to cache for games)"; exit 1; }
              echo "OK: X3D V-Cache idle default = frequency"
              touch $out
            '';

        # -- F54 area value-canaries (input / sensors / gaming / services / diagnostics) --
        # The module config blocks already evaluate in CI via host eval; these pin
        # each area's load-bearing RESOLVED value, so a wrong-but-well-typed
        # regression that still evals green fails here.
        eval-services-avahi-tunnel-guard =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-services-avahi-tunnel-guard"
            {
              deny = builtins.toJSON cfg.services.avahi.denyInterfaces;
            }
            ''
              echo "avahi.denyInterfaces = $deny"
              case "$deny" in
                *wg0-mullvad*) ;;
                *) echo "FAIL: wg0-mullvad missing -- mDNS/hostname would leak into the Mullvad tunnel"; exit 1 ;;
              esac
              echo "OK: avahi denies the Mullvad tunnel interface"
              touch $out
            '';

        eval-input-yeetmouse-boot =
          let
            mods = inputs.self.nixosConfigurations.ryzen-9950x3d.config.boot.kernelModules;
          in
          pkgs.runCommand "eval-input-yeetmouse-boot"
            {
              hasYeet = builtins.toJSON (builtins.elem "yeetmouse" mods);
            }
            ''
              [[ "$hasYeet" == "true" ]] || { echo "FAIL: yeetmouse not force-loaded at boot (regressed to device-gated load)"; exit 1; }
              echo "OK: yeetmouse in boot.kernelModules"
              touch $out
            '';

        eval-gaming-vklayer =
          let
            vars = inputs.self.nixosConfigurations.ryzen-9950x3d.config.environment.sessionVariables;
          in
          pkgs.runCommand "eval-gaming-vklayer"
            {
              addPath = vars.VK_ADD_LAYER_PATH or "unset";
              hasLegacy = builtins.toJSON (vars ? VK_LAYER_PATH);
            }
            ''
              [[ "$addPath" != "unset" ]] || { echo "FAIL: VK_ADD_LAYER_PATH unset -- driver explicit Vulkan layers off the loader path"; exit 1; }
              [[ "$hasLegacy" == "false" ]] || { echo "FAIL: VK_LAYER_PATH set -- clobbers user mangohud/vkbasalt layers (F21 regressed)"; exit 1; }
              echo "OK: additive VK_ADD_LAYER_PATH set; clobbering VK_LAYER_PATH absent"
              touch $out
            '';

        # Value-only (kmod load-name + driver pname); deliberately reads .pname
        # (cheap) not .drvPath, which would pull the CachyOS kernel closure via
        # IFD. Pinning the pname catches the real regression a bare count misses:
        # a sensor kmod name still in the load-list but its providing package
        # dropped from extraModulePackages, so the .ko silently never builds.
        eval-sensors-drivers =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
            mods = cfg.boot.kernelModules;
            pnames = builtins.toJSON (map (p: p.pname or p.name or "") cfg.boot.extraModulePackages);
          in
          pkgs.runCommand "eval-sensors-drivers"
            {
              hasZen = builtins.toJSON (builtins.elem "zenpower" mods);
              hasSmu = builtins.toJSON (builtins.elem "ryzen_smu" mods);
              inherit pnames;
            }
            ''
              [[ "$hasZen" == "true" ]] || { echo "FAIL: zenpower not in boot.kernelModules"; exit 1; }
              [[ "$hasSmu" == "true" ]] || { echo "FAIL: ryzen_smu not in boot.kernelModules"; exit 1; }
              [[ "$pnames" == *zenpower* ]] || { echo "FAIL: zenpower kmod load-name set but its driver package dropped from extraModulePackages"; exit 1; }
              [[ "$pnames" == *ryzen-smu* ]] || { echo "FAIL: ryzen_smu kmod load-name set but its driver package dropped from extraModulePackages"; exit 1; }
              echo "OK: zenpower + ryzen_smu kmods wired AND their out-of-tree driver packages present"
              touch $out
            '';

        # Value-only (enable flag); does NOT force the kernel-matched turbostat
        # drvPath, which would pull the CachyOS kernel via IFD.
        eval-diagnostics-turbostat =
          let
            cfg = inputs.self.nixosConfigurations.ryzen-9950x3d.config;
          in
          pkgs.runCommand "eval-diagnostics-turbostat"
            {
              enabled = builtins.toJSON cfg.myModules.diagnostics.turbostat.enable;
            }
            ''
              [[ "$enabled" == "true" ]] || { echo "FAIL: turbostat diagnostics not enabled on ryzen"; exit 1; }
              echo "OK: turbostat diagnostics enabled + wired on ryzen"
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
              specCount = toString specCount;
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
                r = builtins.tryEval (set.${n}.drvPath or null);
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
      };
    };
}
