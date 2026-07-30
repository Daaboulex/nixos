# bluetooth — BlueZ stack configuration with optional power-on-boot.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.bluetooth;
    in
    {
      _class = "nixos";
      options.myModules.hardware.bluetooth = {
        enable = lib.mkEnableOption "Bluetooth configuration";
        powerOnBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Power on Bluetooth controller on boot";
        };
      };

      config = lib.mkIf cfg.enable {
        hardware.bluetooth = {
          enable = true;
          inherit (cfg) powerOnBoot;
          settings.General = {
            # Historical note: BlueZ ≥ 5.64 dropped the
            # `Enable = "Source,Sink,Media,Socket"` string — profiles are
            # now gated per-plugin at daemon load. Don't add it back; it
            # produces "Unknown key Enable for group General" in bluetoothd
            # logs on every start.
            Experimental = true;
            KernelExperimental = true; # Enable ISO socket for LE Audio BAP
          };
        };

        # NixOS powerOnBoot only sets Policy.AutoEnable — it does NOT unblock rfkill.
        # On hosts that WANT BT at boot (Qualcomm WCN785x on ryzen-9950x3d starts
        # soft-blocked by firmware), we rfkill-unblock at service start so
        # bluetoothd can power on the adapter and not fail with 0x03 "hardware
        # failure" when trying to set controller mode.
        #
        # Gated on powerOnBoot: if the host sets powerOnBoot=false (e.g.
        # macbook-pro-9-2, where BT is on-demand to save battery), we do NOT
        # unblock rfkill at boot. Otherwise the daemon loads paired devices
        # into a soft-blocked controller and logs "Failed to set mode" +
        # "Failed to add device" noise on every boot.
        systemd.services.bluetooth.serviceConfig.ExecStartPre = lib.mkIf cfg.powerOnBoot [
          "${pkgs.util-linux}/bin/rfkill unblock bluetooth"
        ];

        users.users.${config.myModules.primaryUser}.extraGroups = [ "bluetooth" ];
      };
    };
in
{
  flake.modules.nixos.hardware-bluetooth = mod;

}
