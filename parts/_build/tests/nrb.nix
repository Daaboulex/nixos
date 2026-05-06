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

        # ── VM integration tests (nixosTest) ─────────────────────────────

        vm-nrb-build-fail-timing = pkgs.testers.nixosTest {
          name = "nrb-build-fail-timing";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.users
              inputs.self.modules.nixos.nix-nix
            ];
            myModules = {
              users.enable = true;
              nix.nix.enable = true;
            };
            environment.systemPackages = [
              nrbTest
              pkgs.zsh
              pkgs.git
            ];
            virtualisation.memorySize = 2048;
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
            imports = [
              inputs.self.modules.nixos.users
              inputs.self.modules.nixos.nix-nix
            ];
            myModules = {
              users.enable = true;
              nix.nix.enable = true;
            };
            environment.systemPackages = [
              nrbTest
              pkgs.zsh
            ];
            virtualisation.memorySize = 1024;
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")

            # Create flake dir so nrb passes the directory check before hitting daemon check
            machine.succeed("mkdir -p /tmp/test-flake && echo '{ outputs = _: {}; }' > /tmp/test-flake/flake.nix")

            # Stop the nix daemon
            machine.succeed("systemctl stop nix-daemon.socket nix-daemon.service")

            # nrb should fail cleanly with daemon error
            output = machine.fail("FLAKE_DIR=/tmp/fake nrb-test 2>&1")
            assert "Nix daemon not responding" in output, f"Expected daemon error, got: {output[:200]}"
          '';
        };
      };
    };
}
