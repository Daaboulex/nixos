# controllers — game controller support: PlayStation and Xbox pads over USB and Bluetooth.
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
      cfg = config.myModules.input.controllers;
    in
    {
      _class = "nixos";

      options.myModules.input.controllers = {
        enable = lib.mkEnableOption ''
          game controller support. Everything mainstream is already in-kernel
          and autoloads on hotplug: DualSense/Edge and DualShock 4
          (hid_playstation: rumble, lightbar, touchpad, gyro, USB and
          Bluetooth), DualShock 3 wired (hid_sony), Xbox 360/One/Series wired
          plus the 360 wireless receiver (xpad), Bluetooth Xbox pads with basic
          rumble (hid_microsoft) - and systemd's stock 70-uaccess rule grants
          seat users every ID_INPUT_JOYSTICK device. This module only carries
          the deliberate opt-ins below; with none of them set, enabling it
          changes nothing'';

        udevRules = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            game-devices-udev-rules plus uinput, the hidraw/remapper access
            layer for a host WITHOUT the Steam module: SDL HIDAPI features
            (gyro, lightbar, trigger effects) need user-readable hidraw nodes.
            Redundant next to myModules.gaming.steam - steam-hardware already
            ships Valve's rule set with the Sony pads' hidraw entries and
            loads uinput.
          '';
        };

        xboxBluetooth = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            xpadneo for Bluetooth Xbox pads: trigger rumble, battery reporting,
            Elite 2 paddles, correct SDL mappings, BLE-firmware pads. The
            in-kernel hid_microsoft already drives them with basic rumble, so
            this out-of-tree module (rebuilt on every kernel bump) is an
            upgrade, not a requirement.
          '';
        };

        xboxDongle = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            xone for the Xbox Wireless USB dongle. Needs the unfree Microsoft
            dongle firmware, blacklists xpad and mt76x2u, and substitutes
            xpad-noone, which moves wired Xbox One/Series pads onto xone.
            Enable only when the dongle is actually used.
          '';
        };

        ds3Bluetooth = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Let a DualShock 3 connect over Bluetooth by relaxing bluez's
            ClassicBondedOnly, which re-exposes the CVE-2023-45866 class
            (classic-HID injection while the adapter is connectable) - bluez
            defaults it closed since 5.71 and the DS3 never bonds. Pairing:
            plug in once by cable (the bluez sixaxis plugin writes the host as
            the pad's master), approve the agent prompt, unplug, press PS.
            Wired DS3 works without any of this.
          '';
        };

        dualsensectl = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "dualsensectl CLI for DualSense lightbar, player LEDs, microphone LED, and trigger effects.";
        };
      };

      config = lib.mkIf cfg.enable {
        hardware.uinput.enable = lib.mkIf cfg.udevRules true;
        services.udev.packages = lib.optional cfg.udevRules pkgs.game-devices-udev-rules;

        hardware.xpadneo.enable = lib.mkIf cfg.xboxBluetooth true;
        hardware.xone.enable = lib.mkIf cfg.xboxDongle true;

        hardware.bluetooth.input = lib.mkIf cfg.ds3Bluetooth {
          General.ClassicBondedOnly = false;
        };

        environment.systemPackages = lib.optional cfg.dualsensectl pkgs.dualsensectl;

        assertions = [
          {
            assertion = !cfg.ds3Bluetooth || config.hardware.bluetooth.enable;
            message = "myModules.input.controllers.ds3Bluetooth requires hardware.bluetooth.enable";
          }
        ];
      };
    };
in
{
  flake.modules.nixos.input-controllers = mod;

}
