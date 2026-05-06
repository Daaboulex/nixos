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
              if output=$(nrb-test --deploy testhost --boot 2>&1); then
                echo "FAIL: --boot with --deploy not rejected"
                echo "$output"
                exit 1
              fi
              echo "$output" | grep -q "does not support --boot" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --deploy --boot rejected"
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
              echo "$output" | grep -q "does not support --update" \
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
              echo "$output" | grep -q "does not support --update-no-kernel" \
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
              echo "$output" | grep -q "Unknown flag" \
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
              echo "$output" | grep -q "Usage:" \
                || { echo "FAIL: --help missing Usage:"; echo "$output"; exit 1; }
              echo "OK: --help shows usage"
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
              echo "$output" | grep -q "cannot be combined" \
                || { echo "FAIL: wrong error message"; echo "$output"; exit 1; }
              echo "OK: --host --deploy rejected"
              touch $out
            '';

        # Note: --update + --update-no-kernel mutual exclusion (line 307) is checked
        # AFTER hostname/flakeDir/daemon preflight, so it can't be tested in a
        # runCommand sandbox. It's pre-existing behavior, not a new fix.

        nrb-activate-regex-test =
          pkgs.runCommand "nrb-activate-regex-test" { }
            ''
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

        # ── VM integration tests (nixosTest) ─────────────────────────────

        vm-nrb-build-fail-timing = pkgs.testers.nixosTest {
          name = "nrb-build-fail-timing";
          nodes.machine = {
            virtualisation.memorySize = 2048;
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
            machine.wait_for_unit("nix-daemon.service")

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
