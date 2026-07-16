# nrb system tests — flag validation (runCommand) + VM integration (nixosTest).
# Run individual: nix build .#checks.x86_64-linux.<test-name>
# Run all: nix flake check
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      nrbFns = import ../../../home/modules/zsh/nrb-functions.nix {
        inherit pkgs;
        flakeDir = "/tmp/test-flake";
      };

      nrbScript = pkgs.writeText "nrb-functions.zsh" ''
        ${nrbFns.nrb}
      '';

      nrbTest = pkgs.writeShellScriptBin "nrb-test" ''
        # nrb's host-safety preflight calls `hostname`; provide it in the
        # check sandbox (present at real runtime, absent in runCommand's PATH).
        export PATH=${pkgs.nettools}/bin:$PATH
        exec ${pkgs.zsh}/bin/zsh -c 'source ${nrbScript} && nrb "$@"' -- "$@"
      '';
    in
    {
      checks = {
        # ── Flag compatibility (runCommand) ──────────────────────────────

        nrb-flag-compat-boot-deploy =
          pkgs.runCommand "nrb-flag-compat-boot-deploy"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              # --boot IS supported for cross-arch deploy; the arch restriction is
              # enforced AFTER target resolution (nrb-functions.nix), not at flag
              # validation. So nrb must NOT reject --boot here — it proceeds and
              # fails to reach the fake target, which is the expected path.
              output=$(nrb-test --deploy testhost --boot 2>&1) || true
              if grep -q "does not support --boot" <<< "$output"; then
                echo "FAIL: --deploy --boot wrongly rejected at flag validation"
                echo "$output"; exit 1
              fi
              grep -q "Cannot reach testhost" <<< "$output" \
                || { echo "FAIL: expected target-resolution attempt, got:"; echo "$output"; exit 1; }
              echo "OK: --deploy --boot accepted (arch restriction enforced post-resolution)"
              touch $out
            '';

        nrb-flag-compat-install-sync =
          pkgs.runCommand "nrb-flag-compat-install-sync"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --install testhost root@testhost --sync other 2>&1); then
                echo "FAIL: --install with --sync not rejected"
                echo "$output"
                exit 1
              fi
              grep -q "cannot be combined" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --install --sync rejected"
              touch $out
            '';

        nrb-flag-compat-install-args =
          pkgs.runCommand "nrb-flag-compat-install-args"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --install testhost 2>&1); then
                echo "FAIL: --install with a missing target not rejected"
                echo "$output"
                exit 1
              fi
              grep -q "requires <host> and <root@target>" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --install requires host + target"
              touch $out
            '';

        nrb-flag-compat-update-deploy =
          pkgs.runCommand "nrb-flag-compat-update-deploy"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --deploy testhost --update 2>&1); then
                echo "FAIL: --update with --deploy not rejected"
                echo "$output"
                exit 1
              fi
              grep -q "does not support --update" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --deploy --update rejected"
              touch $out
            '';

        nrb-flag-compat-update-no-kernel-deploy =
          pkgs.runCommand "nrb-flag-compat-update-no-kernel-deploy"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --deploy testhost --update-no-kernel 2>&1); then
                echo "FAIL: --update-no-kernel with --deploy not rejected"
                echo "$output"
                exit 1
              fi
              grep -q "does not support --update-no-kernel" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --deploy --update-no-kernel rejected"
              touch $out
            '';

        nrb-flag-unknown =
          pkgs.runCommand "nrb-flag-unknown"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --bogus 2>&1); then
                echo "FAIL: unknown flag accepted"
                echo "$output"
                exit 1
              fi
              grep -q "Unknown flag" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: unknown flag rejected"
              touch $out
            '';

        nrb-help-output =
          pkgs.runCommand "nrb-help-output"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              nrb-test --help > /dev/null 2>&1 || { echo "FAIL: --help exited nonzero"; exit 1; }
              output=$(nrb-test --help 2>&1)
              grep -q "Usage:" <<< "$output" \
                || { echo "FAIL: --help missing Usage:"; echo "$output"; exit 1; }
              grep -q -- "--sync" <<< "$output" \
                || { echo "FAIL: --help missing --sync:"; echo "$output"; exit 1; }
              echo "OK: --help shows usage"
              touch $out
            '';

        nrb-flag-sync-requires-target =
          pkgs.runCommand "nrb-flag-sync-requires-target"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --sync 2>&1); then
                echo "FAIL: --sync without target accepted"
                echo "$output"
                exit 1
              fi
              grep -q -- "--sync requires" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --sync requires a target"
              touch $out
            '';

        nrb-flag-compat-sync-deploy =
          pkgs.runCommand "nrb-flag-compat-sync-deploy"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --sync foo --deploy bar 2>&1); then
                echo "FAIL: --sync with --deploy not rejected"
                echo "$output"
                exit 1
              fi
              grep -q -- "--sync cannot be combined" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --sync --deploy rejected"
              touch $out
            '';

        nrb-flag-compat-host-deploy =
          pkgs.runCommand "nrb-flag-compat-host-deploy"
            {
              nativeBuildInputs = [ nrbTest ];
            }
            ''
              set -euo pipefail
              if output=$(nrb-test --host foo --deploy bar 2>&1); then
                echo "FAIL: --host with --deploy not rejected"
                echo "$output"
                exit 1
              fi
              grep -q "cannot be combined" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --host --deploy rejected"
              touch $out
            '';

        nrb-flag-spec-base-exclusive =
          pkgs.runCommand "nrb-flag-spec-base-exclusive" { nativeBuildInputs = [ nrbTest ]; }
            ''
              set -euo pipefail
              if output=$(nrb-test --spec vfio-amd --base 2>&1); then
                echo "FAIL: --spec with --base not rejected"; echo "$output"; exit 1
              fi
              grep -q "cannot be combined" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --spec --base rejected"
              touch $out
            '';

        nrb-flag-spec-deploy-exclusive =
          pkgs.runCommand "nrb-flag-spec-deploy-exclusive" { nativeBuildInputs = [ nrbTest ]; }
            ''
              set -euo pipefail
              if output=$(nrb-test --spec vfio-amd --deploy bar 2>&1); then
                echo "FAIL: --spec with --deploy not rejected"; echo "$output"; exit 1
              fi
              grep -q "local activation only" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --spec --deploy rejected"
              touch $out
            '';

        nrb-flag-spec-check-exclusive =
          pkgs.runCommand "nrb-flag-spec-check-exclusive" { nativeBuildInputs = [ nrbTest ]; }
            ''
              set -euo pipefail
              if output=$(nrb-test --base --check 2>&1); then
                echo "FAIL: --base with --check not rejected"; echo "$output"; exit 1
              fi
              grep -q "no effect with --check" <<< "$output" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --base --check rejected"
              touch $out
            '';

        # Note: --update + --update-no-kernel mutual exclusion (line 307) is checked
        # AFTER hostname/flakeDir/daemon preflight, so it can't be tested in a
        # runCommand sandbox. It's pre-existing behavior, not a new fix.

        nrb-activate-regex-test = pkgs.runCommand "nrb-activate-regex-test" { } ''
          set -euo pipefail
          # Test the regex used by nrb-activate (hardening.nix:46)
          valid="abcdefghijklmnopqrstuvwxyz012345-nixos-system-ryzen"
          invalid1="../../etc/shadow"
          invalid2="ABCDEFGHIJKLMNOPQRSTUVWXYZ012345-nixos-system-evil"
          invalid3="abcdefghijklmnopqrstuvwxyz01234-nixos-system-short"

          [[ "$valid" =~ ^[a-z0-9]{32}-nixos-system-.+ ]] \
            || { echo "FAIL: valid basename rejected"; exit 1; }
          [[ ! "$invalid1" =~ ^[a-z0-9]{32}-nixos-system-.+ ]] \
            || { echo "FAIL: path traversal accepted"; exit 1; }
          [[ ! "$invalid2" =~ ^[a-z0-9]{32}-nixos-system-.+ ]] \
            || { echo "FAIL: uppercase accepted"; exit 1; }
          [[ ! "$invalid3" =~ ^[a-z0-9]{32}-nixos-system-.+ ]] \
            || { echo "FAIL: short hash (31 char) accepted"; exit 1; }

          echo "OK: nrb-activate regex validation correct"
          touch $out
        '';

        # Specialisation-name validation in nrb-activate's optional 3rd arg
        # (hardening.nix) — only [a-zA-Z0-9_-]+ may name a sub-closure to
        # activate, so the arg can never escape the verified base path.
        nrb-activate-spec-regex-test = pkgs.runCommand "nrb-activate-spec-regex-test" { } ''
          set -euo pipefail
          for ok in vfio-amd multiseat vfio_all v123; do
            [[ "$ok" =~ ^[a-zA-Z0-9_-]+$ ]] \
              || { echo "FAIL: valid spec '$ok' rejected"; exit 1; }
          done
          for bad in "../base" "a/b" "a b" "a;rm" ""; do
            [[ ! "$bad" =~ ^[a-zA-Z0-9_-]+$ ]] \
              || { echo "FAIL: invalid spec '$bad' accepted"; exit 1; }
          done
          echo "OK: nrb-activate spec-name validation correct"
          touch $out
        '';

        # The booted-specialisation detector parses the boot entry's init= path.
        # Proves: a /specialisation/<name>/ init yields <name>; a base init
        # yields "".
        nrb-booted-spec-test = pkgs.runCommand "nrb-booted-spec-test" { } ''
          set -euo pipefail
          _detect() {
            local init rest
            init=$(printf '%s\n' "$1" | grep -oE 'init=[^ ]+' | head -1)
            [[ "$init" == */specialisation/* ]] || return 0
            rest="''${init#*/specialisation/}"
            printf '%s' "''${rest%%/*}"
          }
          spec=$(_detect "initrd=\\efi BOOT_IMAGE=/kernel init=/nix/store/abc-nixos-system-host/specialisation/vfio-amd/init root=fstab")
          [[ "$spec" == "vfio-amd" ]] \
            || { echo "FAIL: expected vfio-amd, got '$spec'"; exit 1; }
          base=$(_detect "BOOT_IMAGE=/kernel init=/nix/store/abc-nixos-system-host/init root=fstab")
          [[ -z "$base" ]] \
            || { echo "FAIL: base entry should yield empty, got '$base'"; exit 1; }
          echo "OK: booted-spec detector correct"
          touch $out
        '';

        # ── VM integration tests (nixosTest) ─────────────────────────────

        vm-nrb-build-fail-timing = pkgs.testers.nixosTest {
          name = "nrb-build-fail-timing";
          nodes.machine = {
            virtualisation.memorySize = 1024;
            virtualisation.graphics = false;
            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
            # NOPASSWD sudo so nrb passes sudo -v and reaches the build phase.
            # Without this, nrb exits at sudo check and the C1/C2 hang fix is never exercised.
            security.sudo.extraRules = [
              {
                users = [ "root" ];
                commands = [
                  {
                    command = "ALL";
                    options = [ "NOPASSWD" ];
                  }
                ];
              }
            ];
            environment.systemPackages = [
              nrbTest
              pkgs.zsh
              pkgs.git
            ];
          };
          testScript = ''
            import time

            machine.wait_for_unit("multi-user.target")
            # socket-activated: the .service is inactive until used; wait on the socket
            machine.wait_for_unit("nix-daemon.socket")

            # Create a broken flake that fails at eval (no nixpkgs needed)
            machine.succeed("mkdir -p /tmp/test-flake")
            machine.succeed("""cat > /tmp/test-flake/flake.nix << 'FLAKE'
            {
              outputs = { ... }: {
                nixosConfigurations.machine = throw "intentional eval failure";
              };
            }
            FLAKE""")
            machine.succeed("cd /tmp/test-flake && git init && git add .")

            # Time the nrb invocation — must return in <30s (not 60s)
            start = time.monotonic()
            machine.fail("FLAKE_DIR=/tmp/test-flake nrb-test 2>&1")
            elapsed = time.monotonic() - start

            assert elapsed < 30, f"nrb took {elapsed:.1f}s on build failure (hang if >30s)"
            machine.log(f"nrb returned in {elapsed:.1f}s — no hang detected")
          '';
        };

        vm-nrb-preflight-no-daemon = pkgs.testers.nixosTest {
          name = "nrb-preflight-no-daemon";
          nodes.machine = {
            virtualisation.memorySize = 512;
            virtualisation.graphics = false;
            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
            environment.systemPackages = [
              nrbTest
              pkgs.zsh
            ];
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Create flake dir so nrb passes the directory check before hitting daemon check
            machine.succeed("mkdir -p /tmp/test-flake && echo '{ outputs = _: {}; }' > /tmp/test-flake/flake.nix")

            # Stop the nix daemon
            machine.succeed("systemctl stop nix-daemon.socket nix-daemon.service")

            # nrb should fail cleanly with daemon error
            output = machine.fail("FLAKE_DIR=/tmp/test-flake nrb-test 2>&1")
            assert "Nix daemon not responding" in output, f"Expected daemon error, got: {output[:200]}"
          '';
        };
      };
    };
}
