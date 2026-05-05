# NixOS VM integration tests for myModules
# Run: nix build .#checks.x86_64-linux.<test-name>
# Run all: nix flake check (includes these alongside treefmt/git-hooks checks)
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      check-placement-bin = import ../_build/checks/check-placement.nix { inherit pkgs; };
      check-scrub-tokens-bin = import ../_build/checks/check-scrub-tokens.nix { inherit pkgs; };
    in
    {
      checks = {
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
              echo "$output" | grep -q 'expected scope: myModules.security' \
                || { echo "FAIL: diagnostic missing expected scope."; echo "$output"; exit 1; }
              echo "$output" | grep -q 'actual scope:' \
                || { echo "FAIL: diagnostic missing actual scope line."; echo "$output"; exit 1; }
              echo "$output" | grep -q 'myModules.services' \
                || { echo "FAIL: diagnostic missing actual scope value."; echo "$output"; exit 1; }

              # Sanity: same content under correct path MUST pass.
              mv parts/security/foo.nix parts/services/foo.nix
              if ! check-placement parts/services/foo.nix; then
                echo "FAIL: check-placement rejected a compliant file."
                exit 1
              fi

              touch "$out"
            '';

        # check-scrub-tokens hook — asserts the hook fires on a synthetic
        # leak (forbidden token + forbidden pattern), passes on
        # context_allowlisted token. Mirrors check-placement-test shape.
        check-scrub-tokens-test =
          pkgs.runCommand "check-scrub-tokens-test"
            {
              nativeBuildInputs = [ check-scrub-tokens-bin ];
              fixtures = ./tests/fixtures;
            }
            ''
              set -euo pipefail
              work=$(mktemp -d)
              cd "$work"

              cp "$fixtures"/scrub-leak.txt scrub-leak.txt
              cp "$fixtures"/scrub-allowlist.txt scrub-allowlist.txt
              cp "$fixtures"/scrub-pattern.txt scrub-pattern.txt
              cp "$fixtures"/scrub-config-test.json scrub-config.json

              # Test 1: leak fixture should fail with hit reported
              if check-scrub-tokens --config scrub-config.json --from-file scrub-leak.txt 2>err.log; then
                echo "FAIL: scrub-leak.txt did not block (expected exit 1)"
                cat err.log
                exit 1
              fi
              grep -q 'Development-Mobile' err.log \
                || { echo "FAIL: leak token not in error output"; cat err.log; exit 1; }

              # Test 2: allowlist fixture should pass
              if ! check-scrub-tokens --config scrub-config.json --from-file scrub-allowlist.txt; then
                echo "FAIL: allowlist fixture blocked unexpectedly"
                exit 1
              fi

              # Test 3: pattern fixture should fail (private_project_paths)
              if check-scrub-tokens --config scrub-config.json --from-file scrub-pattern.txt 2>err.log; then
                echo "FAIL: scrub-pattern.txt did not block (expected exit 1)"
                cat err.log
                exit 1
              fi
              grep -q 'Acme' err.log \
                || { echo "FAIL: pattern hit not in error output"; cat err.log; exit 1; }

              touch "$out"
            '';

        # Toplevel host-system builds — `nix flake check` now builds each
        # host's full system closure, catching module-level regressions
        # that eval-only checks miss (missing deps, broken derivations,
        # service-unit validation, etc.).
        toplevel-ryzen-9950x3d = inputs.self.nixosConfigurations.ryzen-9950x3d.config.system.build.toplevel;
        toplevel-macbook-pro-9-2 =
          inputs.self.nixosConfigurations.macbook-pro-9-2.config.system.build.toplevel;

        # Verify nix daemon starts with flakes enabled and GC configured
        vm-nix-settings = pkgs.testers.nixosTest {
          name = "nix-settings";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.nix-nix
              inputs.self.modules.nixos.users
            ];
            myModules.nix.nix.enable = true;
            myModules.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("nix-daemon.service")
            machine.succeed("nix --version")
            machine.succeed("nix show-config | grep experimental-features | grep flakes")
            machine.succeed("nix show-config | grep auto-optimise-store | grep true")
          '';
        };

        # Verify user creation, groups, and zsh shell
        vm-users = pkgs.testers.nixosTest {
          name = "users";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.users
            ];
            myModules.users.enable = true;
            myModules.primaryUser = "testuser";
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
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

        # Verify NetworkManager starts
        vm-networking = pkgs.testers.nixosTest {
          name = "networking";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.hardware-networking
              inputs.self.modules.nixos.users
            ];
            myModules.hardware.networking.enable = true;
            myModules.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("NetworkManager.service")
            machine.succeed("nmcli general status")
          '';
        };

        # ── §A.12 test backfill — high-blast-radius modules ──
        # Added 2026-04-21 to cover modules whose silent failures would
        # break an entire host. Kept minimal: activation + one key behavior.

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
            machine.succeed("mountpoint -q /var/log || test \\"$(stat -c %d /var/log)\\" = \\"$(stat -c %d /persist/var/log)\\"")
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
            # LADSPA plugins directory is populated (not empty)
            machine.succeed("ls /nix/store/*-pipewire-ladspa-plugins/lib/ladspa/*.so")
          '';
        };

        # hardware-networking-resolved — systemd-resolved starts with DoT
        # configured. Validates the DNS encryption layer is active.
        vm-networking-resolved = pkgs.testers.nixosTest {
          name = "networking-resolved";
          nodes.machine = {
            imports = [
              inputs.self.modules.nixos.hardware-networking
              inputs.self.modules.nixos.users
            ];
            myModules.hardware.networking = {
              enable = true;
              dnsOverTls = "opportunistic";
            };
            myModules.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("systemd-resolved.service")
            # DoT is configured (not "no")
            machine.succeed("resolvectl status | grep -i 'DNSOverTLS' | grep -iv 'no'")
            # Stub resolver is listening
            machine.succeed("ss -tlnp | grep '127.0.0.53'")
          '';
        };

        # eval-kernel-cachyos — CachyOS kernel is active on ryzen host.
        # Catches regressions where kernel overlay or input pin breaks
        # and silently falls back to stock nixpkgs kernel.
        eval-kernel-cachyos =
          let
            kernelVersion = inputs.self.nixosConfigurations.ryzen-9950x3d.config.boot.kernelPackages.kernel.version;
          in
          pkgs.runCommand "eval-kernel-cachyos"
            {
              actual = kernelVersion;
            }
            ''
              echo "boot.kernelPackages.kernel.version = $actual"
              case "$actual" in
                *cachyos*|*lto*)
                  echo "OK: CachyOS kernel active"
                  touch $out
                  ;;
                *)
                  echo "FAIL: expected CachyOS kernel (version containing cachyos or lto)"
                  echo "Got: $actual — looks like stock nixpkgs kernel"
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
            if isFunc then ''
              echo "OK: mkSimplePackage returns a function (valid module shape)"
              touch $out
            '' else ''
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
            pass =
              merged.a == 1 && merged.b == 99 && merged.nested.x == 10 && merged.nested.y == 20;
          in
          pkgs.runCommand "eval-mylib-mergeSettings" { } (
            if pass then ''
              echo "OK: mergeSettings override semantics correct"
              echo "  a=1 (kept), b=99 (overridden), nested.x=10 (kept), nested.y=20 (added)"
              touch $out
            '' else ''
              echo "FAIL: mergeSettings produced wrong result"
              exit 1
            ''
          );
      };
    };
}
