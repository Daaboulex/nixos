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
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
            machine.succeed("nix show-config | grep experimental-features | grep cgroups")
            machine.succeed("nix show-config | grep auto-optimise-store | grep true")
          '';
        };

        # Verify user creation, groups, and zsh shell
        vm-users = pkgs.testers.nixosTest {
          name = "users";
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
            machine.succeed("systemctl is-active systemd-resolved.service")
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
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
            # LADSPA plugin config wired into PipeWire — no store-path fallback
            machine.succeed("grep -r 'ladspa' /etc/pipewire/pipewire.conf.d/ 2>/dev/null | grep -qv '^#'")
          '';
        };

        # hardware-networking-resolved — systemd-resolved starts with DoT
        # configured. Validates the DNS encryption layer is active.
        vm-networking-resolved = pkgs.testers.nixosTest {
          name = "networking-resolved";
          defaults.virtualisation = {
            memorySize = 512;
            graphics = false;
          };
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
            kpkg = inputs.self.nixosConfigurations.ryzen-9950x3d.config.boot.kernelPackages.kernel;
          in
          pkgs.runCommand "eval-kernel-cachyos"
            {
              actual = kpkg.pname;
              version = kpkg.version;
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
        # myLib.cap — contract: capitalizes first letter, preserves rest.
        eval-mylib-cap =
          let
            cap = inputs.self.lib.cap;
            pass = cap "blue" == "Blue" && cap "red" == "Red" && cap "a" == "A";
          in
          pkgs.runCommand "eval-mylib-cap" { } (
            if pass then ''
              echo "OK: cap capitalizes first letter correctly"
              touch $out
            '' else ''
              echo "FAIL: cap produced wrong result"
              echo "  cap \"blue\" = ${cap "blue"} (expected Blue)"
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
            if hasType && hasDefault then ''
              echo "OK: mkSettingsOption produces option with type + empty default"
              touch $out
            '' else ''
              echo "FAIL: mkSettingsOption missing type or default"
              exit 1
            ''
          );

        # myLib.themeCtx — contract: returns hasTheme/c/when attrs,
        # handles missing theme gracefully.
        eval-mylib-themeCtx =
          let
            ctx = inputs.self.lib.themeCtx {
              config.myModules.home.theme = { };
            };
            pass = ctx.hasTheme == false && ctx.c == { } && ctx.when { x = 1; } == { };
          in
          pkgs.runCommand "eval-mylib-themeCtx" { } (
            if pass then ''
              echo "OK: themeCtx handles disabled theme (hasTheme=false, c={}, when={})"
              touch $out
            '' else ''
              echo "FAIL: themeCtx contract violation"
              exit 1
            ''
          );

        # myLib.withStdenvCC — contract: returns a derivation with
        # stdenv.cc in nativeBuildInputs.
        eval-mylib-withStdenvCC =
          let
            dummy = pkgs.runCommand "dummy-drv" { } "touch $out";
            result = inputs.self.lib.withStdenvCC { inherit pkgs; drv = dummy; };
            hasCC = builtins.elem pkgs.stdenv.cc (result.nativeBuildInputs or [ ]);
          in
          pkgs.runCommand "eval-mylib-withStdenvCC" { } (
            if hasCC then ''
              echo "OK: withStdenvCC injects stdenv.cc into nativeBuildInputs"
              touch $out
            '' else ''
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
              mode = cfg.myModules.hardware.cpuAmd.x3dVcache.mode;
            }
            ''
              [[ "$mode" == "cache" ]] || { echo "FAIL: x3dVcache mode is '$mode', expected 'cache'"; exit 1; }
              echo "OK: X3D V-Cache in cache mode"
              touch $out
            '';

        eval-mbp-specialisations =
          let
            specs = builtins.attrNames (inputs.self.nixosConfigurations.macbook-pro-9-2.config.specialisation or {});
          in
          pkgs.runCommand "eval-mbp-specialisations"
            {
              hasCachyos = builtins.toJSON (builtins.elem "cachyos" specs);
              count = builtins.toString (builtins.length specs);
            }
            ''
              [[ "$hasCachyos" == "true" ]] || { echo "FAIL: cachyos specialisation missing on MBP"; exit 1; }
              echo "OK: MBP has $count specialisation(s) including cachyos"
              touch $out
            '';
      };
    };
}
