# flake-module — nixosConfiguration for pixel-9-pro (AVF Linux VM on Pixel 9 Pro).
#
# exhaustiveness-exclude:
#   boot-loader boot-etc-overlay boot-hibernate boot-impermanence boot-kernel boot-module-guards
#   desktop-displays desktop-flatpak desktop-plasma
#   diagnostics-nftables diagnostics-turbostat
#   gaming-gamemode gaming-gamescope gaming-rocksmith gaming-steam
#   hardware-acpid hardware-bluetooth hardware-coolercontrol hardware-core
#   hardware-cpu-amd hardware-cpu-intel hardware-goxlr hardware-gpu-amd
#   hardware-gpu-intel hardware-gpu-nvidia hardware-graphics
#   hardware-networking hardware-pipewire hardware-power hardware-udev-access hardware-upower
#   hardware-usb-power hardware-usbmuxd hardware-rift-cv1
#   host
#   input-ducky-one-x-mini input-libinput input-ratbagd input-streamcontroller
#   input-yeetmouse
#   hardware-hid-apple hardware-mbpfan hardware-broadcom-wifi hardware-smartd
#   nix-nix-ld
#   security-agenix security-hardening security-portmaster
#   security-portmaster-mullvad-compat security-portmaster-split-tunnel-compat
#   sensors-it87 sensors-msr sensors-nct6775 sensors-ryzen-smu sensors-zenpower
#   services-cups services-earlyoom services-geoclue
#   services-mullvad services-sunshine services-split-tunnel
#   storage-btrbk storage-filesystems storage-fstrim
#   tuning-cachyos tuning-corecycler tuning-performance tuning-sysctls
#   vfio-base vfio-device-binding vfio-evdev vfio-hugepages vfio-kvmfr
#   vfio-session-gpu vfio-vms
#
# This is a minimal AVF VM — most NixOS modules are excluded. Only nix
# daemon, SSH, and user config are needed. Hardware is virtual (crosvm).
{ inputs, ... }:
{
  flake.nixosConfigurations.pixel-9-pro = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs;
      myLib = inputs.self.lib;
      site = import inputs.site;
    };
    modules = [
      # Host config
      ./default.nix

      # Platform — replaces the deprecated nixosSystem `system` argument.
      { nixpkgs.hostPlatform = "aarch64-linux"; }

      # nixos-avf hardware module (kernel, virtio, filesystems, networking)
      inputs.nixos-avf.nixosModules.avf

      # Nix
      inputs.self.modules.nixos.nix-nix
      inputs.self.modules.nixos.nix-remote-builder

      # Users
      inputs.self.modules.nixos.users

      # Services
      inputs.self.modules.nixos.services-avahi
      inputs.self.modules.nixos.services-syncthing

      # Security (hardening excluded — conflicts with AVF's sudo/security defaults)
      inputs.self.modules.nixos.security-ssh

      # Home Manager
      ../../../home/home.nix
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
          myLib = inputs.self.lib;
          site = import inputs.site;
        };
        home-manager.sharedModules = [
          inputs.lmstudio.homeManagerModules.default
          inputs.rocksmith-nix.homeManagerModules.default
          inputs.free-claude-code.homeManagerModules.default
        ];
      }

      # Overlays are lazy (see parts/overlays/_default.nix): the x86-only
      # entries cost nothing unless referenced; pixel references only
      # llm-agents.* (hermes) and the python fixes.
      {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [ inputs.self.overlays.default ];
      }
    ];
  };
}
