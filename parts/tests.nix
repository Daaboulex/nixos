# NixOS VM integration tests for myModules
# Run: nix build .#checks.x86_64-linux.<test-name>
# Run all: nix flake check (includes these alongside treefmt/git-hooks checks)
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = {
        # Verify nix daemon starts with flakes enabled and GC configured
        vm-nix-settings = pkgs.nixosTest {
          name = "nix-settings";
          nodes.machine = {
            imports = [
              inputs.self.nixosModules.system-nix
              inputs.self.nixosModules.system-users
            ];
            myModules.system.nix.enable = true;
            myModules.system.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("nix-daemon.service")
            machine.succeed("nix --version")
            machine.succeed("nix show-config | grep experimental-features | grep flakes")
            machine.succeed("nix show-config | grep auto-optimise-store | grep true")
          '';
        };

        # Verify user creation, groups, and zsh shell
        vm-users = pkgs.nixosTest {
          name = "users";
          nodes.machine = {
            imports = [
              inputs.self.nixosModules.system-users
            ];
            myModules.system.users.enable = true;
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
        vm-ssh = pkgs.nixosTest {
          name = "ssh";
          nodes.machine = {
            imports = [
              inputs.self.nixosModules.system-ssh
              inputs.self.nixosModules.system-users
            ];
            myModules.security.ssh.enable = true;
            myModules.system.users.enable = true;
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
        vm-networking = pkgs.nixosTest {
          name = "networking";
          nodes.machine = {
            imports = [
              inputs.self.nixosModules.hardware-networking
              inputs.self.nixosModules.system-users
            ];
            myModules.hardware.networking.enable = true;
            myModules.system.users.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("NetworkManager.service")
            machine.succeed("nmcli general status")
          '';
        };
      };
    };
}
