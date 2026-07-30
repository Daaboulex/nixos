# display-names -- the name each mounted filesystem presents in a file manager.
_:
let
  mod =
    {
      config,
      lib,
      myLib,
      ...
    }:
    let
      cfg = config.myModules.storage.displayNames;
      entries = lib.mapAttrsToList (mountPoint: name: {
        inherit mountPoint name;
        device = config.fileSystems.${mountPoint}.device or null;
      }) cfg;
      matchOf = e: if e.device == null then null else myLib.blockDevice.udevMatch e.device;
    in
    {
      _class = "nixos";
      options.myModules.storage.displayNames = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          "/" = "NixOS";
        };
        description = ''
          Mount point mapped to the name a file manager presents for it. Keyed
          by mount point so the device is derived from the fileSystems entry
          that already declares it, never restated. Sets the udisks HintName,
          which Solid returns ahead of the on-disk label from both
          Device::description and StorageVolume::label -- so the name survives a
          relabel and nothing on disk is rewritten.
        '';
      };
      config = lib.mkIf (cfg != { }) {
        assertions = lib.concatMap (e: [
          {
            assertion = e.device != null;
            message = "myModules.storage.displayNames: '${e.mountPoint}' is not a declared fileSystems mount point, so no device resolves for it";
          }
          {
            assertion = e.device == null || matchOf e != null;
            message = "myModules.storage.displayNames: '${e.mountPoint}' resolves to device '${toString e.device}', which no udev key can match -- use /dev/mapper/, UUID=, LABEL=, /dev/disk/by-uuid/, /dev/disk/by-label/ or /dev/disk/by-partuuid/";
          }
          {
            assertion = builtins.match "[A-Za-z0-9 ._+-]+" e.name != null;
            message = "myModules.storage.displayNames: name '${e.name}' must match [A-Za-z0-9 ._+-]+ -- a quote or backslash would break the generated udev rule";
          }
        ]) entries;
        services.udev.extraRules =
          lib.concatStringsSep "\n" (
            lib.concatMap (
              e:
              lib.optional (matchOf e != null) ''SUBSYSTEM=="block", ${matchOf e}, ENV{UDISKS_NAME}="${e.name}"''
            ) entries
          )
          + "\n";
      };
    };
in
{
  flake.modules.nixos.storage-display-names = mod;
}
