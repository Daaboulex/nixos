{ inputs, ... }:
{
  flake.nixosModules.development =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.development;
    in
    {
      _class = "nixos";
      options.myModules.development = {
        enable = lib.mkEnableOption "Development tools (compilers, build systems, AI assistants)";
        claudeCode = lib.mkEnableOption "Claude Code AI assistant";
        openviking = lib.mkEnableOption "OpenViking context database for AI agents";
        saleae = lib.mkEnableOption "Saleae Logic analyzer and udev rules";
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          environment.systemPackages = with pkgs; [
            # Build tools
            gcc
            gnumake
            cmake
            pkg-config
            python3
            nodejs

            # Dev workflow
            devenv
            nix-prefetch-git
            inputs.gemini-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
            (pkgs.symlinkJoin {
              name = "agy-wrapper";
              paths = [ pkgs.google-antigravity ];
              postBuild = ''
                ln -s $out/bin/antigravity $out/bin/agy
              '';
            })

            # VSCodium, direnv, git, gh: owned by Home Manager modules
          ];
        })

        (lib.mkIf cfg.claudeCode {
          environment.systemPackages = [ pkgs.claude-code ];
        })

        (lib.mkIf cfg.openviking {
          environment.systemPackages = [ pkgs.openviking ];
        })

        (lib.mkIf cfg.saleae {
          environment.systemPackages = [ pkgs.saleae-logic-2 ];
          services.udev.packages = [ pkgs.saleae-logic-2 ];
          services.udev.extraRules = ''
            SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", MODE="0666", GROUP="users"
            KERNEL=="hidraw*", ATTRS{idVendor}=="1fc9", MODE="0666", GROUP="users"
          '';
        })
      ];
    };
}
