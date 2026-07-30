# gpg — GnuPG with optional pinentry agent integration.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.gpg;
in
{
  options.myModules.home.gpg = {
    enable = lib.mkEnableOption "GnuPG";
    pinentry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable pinentry-gtk2 for graphical passphrase prompts.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gpg.enable = true;

    services.gpg-agent = {
      enable = lib.mkDefault true;
      enableZshIntegration = lib.mkDefault true;
      pinentry.package = lib.mkIf cfg.pinentry (lib.mkDefault pkgs.pinentry-gtk2);
      defaultCacheTtl = lib.mkDefault 3600;
      maxCacheTtl = lib.mkDefault 86400;
    };
  };
}
