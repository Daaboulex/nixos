{
  imports = [
    ./overlays.nix
    ./treefmt.nix
    ./git-hooks.nix
    ./tests.nix

    # ── System ──────────────────────────────────────────────────────────
    ./system/boot.nix
    ./system/kernel.nix
    ./system/nix.nix
    ./system/users.nix
    ./system/security.nix
    ./system/ssh.nix
    ./system/sops.nix
    ./system/services.nix
    ./system/filesystems.nix
    ./system/packages.nix
    ./system/impermanence.nix
    ./system/cachyos-settings.nix

    # ── Hardware: CPU & GPU ─────────────────────────────────────────────
    ./hardware/core.nix
    ./hardware/cpu-amd.nix
    ./hardware/cpu-intel.nix
    ./hardware/graphics.nix
    ./hardware/gpu-amd.nix
    ./hardware/gpu-intel.nix
    ./hardware/gpu-nvidia.nix

    # ── Hardware: Subsystems ────────────────────────────────────────────
    ./hardware/audio.nix
    ./hardware/networking.nix
    ./hardware/bluetooth.nix
    ./hardware/performance.nix
    ./hardware/power.nix

    # ── Hardware: Devices ───────────────────────────────────────────────
    ./hardware/goxlr.nix
    ./hardware/yeetmouse/default.nix
    ./hardware/macbook/default.nix
    ./hardware/ducky-one-x-mini.nix
    ./hardware/debugging-probes.nix
    ./hardware/piper.nix
    ./hardware/streamcontroller.nix

    # ── Desktop ─────────────────────────────────────────────────────────
    ./desktop/kde.nix
    ./desktop/displays.nix
    ./desktop/flatpak.nix

    # ── Apps ────────────────────────────────────────────────────────────
    ./apps/gaming.nix
    ./apps/wine.nix
    ./apps/arkenfox.nix
    ./apps/portmaster.nix
    ./apps/tidalcycles.nix

    # ── Tools ───────────────────────────────────────────────────────────
    ./apps/tools/development.nix
    ./apps/tools/sysdiag.nix
    ./apps/tools/iommu.nix

    # ── Hosts ───────────────────────────────────────────────────────────
    ./hosts/ryzen-9950x3d/flake-module.nix
    ./hosts/macbook-pro-9-2/flake-module.nix
  ];

  perSystem =
    {
      config,
      self',
      inputs',
      pkgs,
      system,
      ...
    }:
    {
      # Per-system configuration if needed (e.g. devShells, packages)
    };
}
