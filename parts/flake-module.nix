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
    ./system/services.nix
    ./system/filesystems.nix
    ./system/packages.nix
    ./system/impermanence.nix
    ./system/cachyos-settings.nix

    # ── Security ──────────────────────────────────────────────────────────
    ./security/system.nix
    ./security/ssh.nix
    ./security/sops.nix
    ./security/arkenfox.nix
    ./security/portmaster.nix

    # ── Hardware ───────────────────────────────────────────────────────
    ./hardware/core.nix
    ./hardware/cpu-amd.nix
    ./hardware/cpu-intel.nix
    ./hardware/graphics.nix
    ./hardware/gpu-amd.nix
    ./hardware/gpu-intel.nix
    ./hardware/gpu-nvidia.nix
    ./hardware/audio.nix
    ./hardware/networking.nix
    ./hardware/bluetooth.nix
    ./hardware/performance.nix
    ./hardware/power.nix

    # ── Desktop ─────────────────────────────────────────────────────────
    ./desktop/kde.nix
    ./desktop/displays.nix
    ./desktop/flatpak.nix

    # ── Standalone Modules ─────────────────────────────────────────────
    ./macbook/default.nix
    ./yeetmouse/default.nix
    ./goxlr.nix
    ./coolercontrol.nix
    ./piper.nix
    ./streamcontroller.nix
    ./ducky-one-x-mini.nix
    ./debugging-probes.nix
    ./gaming.nix
    ./development.nix
    ./wine.nix
    ./tidalcycles.nix
    ./sysdiag.nix
    ./iommu.nix
    ./corecycler.nix

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
