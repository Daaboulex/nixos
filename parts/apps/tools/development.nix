{ inputs, ... }: {
  flake.nixosModules.apps-development = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.development.tools;
      cfgTools = config.myModules.tools;
    in {
      options.myModules.development.tools = {
        enable = lib.mkEnableOption "Development Tools";
        helperScripts = lib.mkEnableOption "Enable helper scripts";
      };
      options.myModules.tools.claudeCode.enable = lib.mkEnableOption "Claude Code AI Assistant";

      config = lib.mkIf cfg.enable {
         environment.systemPackages = with pkgs; [
           vscodium
           (pkgs.symlinkJoin {
             name = "agy-wrapper";
             paths = [ pkgs.google-antigravity ];
             postBuild = ''
               ln -s $out/bin/antigravity $out/bin/agy
             '';
           })
           gemini-cli
           (lib.mkIf cfgTools.claudeCode.enable claude-code)
           direnv
           devenv
           nix-prefetch-git
           saleae-logic-2
           gnumake
           cmake
           pkg-config
           gcc
           python3
           nodejs
         ];
         services.udev.packages = [ pkgs.saleae-logic-2 ];
         services.udev.extraRules = ''
           SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", MODE="0666", GROUP="users"
           KERNEL=="hidraw*", ATTRS{idVendor}=="1fc9", MODE="0666", GROUP="users"
         '';
         # Enable helpers if requested
         myModules.tools.sysdiag.enable = lib.mkIf cfg.helperScripts true;
         myModules.tools.listIommuGroups.enable = lib.mkIf cfg.helperScripts true;
         myModules.tools.llmPrep.enable = lib.mkIf cfg.helperScripts true;
      };
    };
}
