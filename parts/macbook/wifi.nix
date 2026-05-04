# wifi — Broadcom BCM4331 WiFi via b43 driver (MacBook Pro 9,2).
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
      cfg = config.myModules.macbook.wifi;
    in
    {
      _class = "nixos";
      options.myModules.macbook.wifi = {
        enable = lib.mkEnableOption "Broadcom BCM4331 WiFi via b43 driver (MacBook Pro 9,2)";
      };
      config = lib.mkIf cfg.enable {
        # BCM4331 (PCI 14e4:4331) is supported by two in-tree drivers:
        #   • brcmsmac (via bcma bus) — deprecated upstream, and the firmware
        #     brcm/bcm43xx-0.fw was removed from recent linux-firmware releases,
        #     leaving the driver loaded but unable to initialise the radio.
        #   • b43 (via ssb bus) — still supported, firmware packaged separately
        #     in nixpkgs as b43Firmware_6_30_163_46 (OpenFWWF-derived).
        # We pick b43 because its firmware story is stable in nixpkgs 2026.
        hardware.enableRedistributableFirmware = lib.mkDefault true;
        hardware.firmware = [ pkgs.b43Firmware_6_30_163_46 ];

        # bcma (brcmsmac's bus) also matches BCM43xx and will claim the card
        # before b43 can bind if left enabled. Flip the blacklist relative to
        # the old brcmsmac config: blacklist bcma, keep ssb.
        boot.blacklistedKernelModules = [ "bcma" ];

        # Load b43 explicitly. Would auto-load via PCI matching once ssb
        # discovers the device, but being explicit surfaces firmware or
        # build issues at boot instead of silently leaving WiFi missing.
        boot.kernelModules = [ "b43" ];

        # b43/bcma S3 resume fix. Root cause (LKML Nov 2011, Rafał Miłecki):
        # bcma_bus_resume() does not reprogram PCI BAR windows for BCM4331's
        # HT-PHY. mac80211 then reads zero EDCA params → WARN_ON(CW_min/CW_max: 0/0).
        # Broadcom never released BCM4331 specs; PM callbacks exist in
        # bcma/host_pci.c but the chip state restoration is broken.
        # Unload b43+bcma before sleep, reload after resume — forces clean
        # probe path. Brief WiFi interruption (~1-2 s) on resume.
        # Source: Launchpad #1058090, Arch/Gentoo wiki, LKML 2011.2.01836.
        systemd.services.b43-sleep = {
          description = "Unload b43/bcma before suspend (BCM4331 resume bug)";
          wantedBy = [ "sleep.target" ];
          before = [ "sleep.target" ];
          unitConfig.StopWhenUnneeded = true;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "b43-sleep-pre" ''
              ${pkgs.util-linux}/bin/rfkill block wifi 2>/dev/null || true
              ${pkgs.kmod}/bin/modprobe -r b43 2>/dev/null || true
              ${pkgs.kmod}/bin/modprobe -r bcma 2>/dev/null || true
              echo "b43-sleep: unloaded b43+bcma before suspend"
            '';
            ExecStop = pkgs.writeShellScript "b43-sleep-post" ''
              ${pkgs.kmod}/bin/modprobe b43 2>/dev/null || true
              ${pkgs.util-linux}/bin/rfkill unblock wifi 2>/dev/null || true
              echo "b43-sleep: reloaded b43 after resume"
            '';
          };
        };
      };
    };
in
{
  flake.modules.nixos.macbook-wifi = mod;

}
