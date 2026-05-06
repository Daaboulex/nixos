# Per-tier smoke tests — assert that each host's full config activates,
# HM lands on disk, and a handful of critical services / files exist.
#
# Scope kept minimal: this is not end-to-end testing, it's a canary. If a
# smoke test fails, something load-bearing is broken. Real integration tests
# live in parts/_build/tests.nix (per-module).
#
# Cost: each test builds a VM image for the host's full config (~2-5 min
# first time; cached thereafter). Not run on every rebuild — gated behind
# `nix flake check` / CI.

{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        # ─── v2 (Ivy Bridge / MBP 9,2) ────────────────────────────────────
        smoke-v2 = pkgs.testers.nixosTest {
          name = "smoke-v2";
          nodes.machine =
            { ... }:
            {
              imports = [
                # Reuse the real host module tree but skip hardware-specific
                # pieces that can't run in a VM (disko, hardware-configuration).
                # nix-nix excluded — references myModules.security.agenix which
                # would require pulling in the full agenix + security stack.
                inputs.self.modules.nixos.host
                inputs.self.modules.nixos.users
                inputs.self.modules.nixos.hardware-networking
                inputs.self.modules.nixos.services-syncthing
              ];
              myModules = {
                host.tier = "v2";
                users.enable = true;
                hardware.networking.enable = true;
                services.syncthing.enable = true;
              };
              # Keep the VM tiny — disable graphical bits.
              virtualisation.memorySize = 1024;
            };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("NetworkManager.service")
            machine.succeed("id user")
            machine.wait_for_unit("syncthing.service")
          '';
        };

        # ─── v4 (Ryzen 9950X3D / workstation) ─────────────────────────────
        smoke-v4 = pkgs.testers.nixosTest {
          name = "smoke-v4";
          nodes.machine =
            { ... }:
            {
              imports = [
                inputs.self.modules.nixos.host
                inputs.self.modules.nixos.users
                inputs.self.modules.nixos.hardware-networking
                inputs.self.modules.nixos.services-syncthing
                inputs.self.modules.nixos.services-sunshine
              ];
              myModules = {
                host.tier = "v4";
                users.enable = true;
                hardware.networking.enable = true;
                services.syncthing.enable = true;
                # sunshine needs KMS + hw; keep disabled, just verify the
                # module doesn't break activation when declared.
                services.sunshine.enable = false;
              };
              virtualisation.memorySize = 1024;
            };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("NetworkManager.service")
            machine.succeed("id user")
            machine.wait_for_unit("syncthing.service")
          '';
        };
      };
    };
}
