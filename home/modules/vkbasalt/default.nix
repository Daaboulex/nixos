# vkbasalt — Vulkan post-processing overlay (CAS/FXAA/SMAA) with configurable shaders.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.vkbasalt;
  shaderCollections = import ./shaders.nix pkgs;
  combinedShaders = pkgs.symlinkJoin {
    name = "combined-reshade-shaders";
    paths = cfg.shaderPackages;
  };
in
{
  options.myModules.home.vkbasalt = {
    enable = lib.mkEnableOption "vkBasalt overlay — Vulkan post-processing with in-game UI";
    effects = lib.mkOption {
      type = lib.types.str;
      default = "cas";
      description = "Default colon-separated effect chain (cas, smaa, fxaa, Vibrance, LiftGammaGain, Tonemap, etc.)";
    };
    casSharpness = lib.mkOption {
      type = lib.types.str;
      default = "0.4";
      description = "Default CAS sharpness (0.0 = subtle, 1.0 = maximum)";
    };
    toggleKey = lib.mkOption {
      type = lib.types.str;
      default = "Home";
      description = "Key to toggle effects on/off in-game";
    };
    overlayKey = lib.mkOption {
      type = lib.types.str;
      default = "F1";
      description = "Key to open the overlay UI in-game";
    };
    enableOnLaunch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Effects enabled automatically when a game launches";
    };
    autoApply = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-apply parameter changes without clicking Apply";
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines for config (ReShade shader parameters like Vibrance, LiftGammaGain values)";
    };
    shaderPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = shaderCollections;
      defaultText = lib.literalExpression "[ <15 shader collections> ]";
      description = "Shader packages providing share/reshade/{Shaders,Textures} — combined into vkBasalt shader/texture paths";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.vkbasalt-overlay
      combinedShaders

      # Wrap the package's vkbasalt-run with HM-specific help text
      # (keybinds and config paths that the package doesn't know about).
      # hiPrio so this wrapper wins over the vkbasalt-overlay package's own vkbasalt-run.
      (lib.hiPrio (
        pkgs.writeShellScriptBin "vkbasalt-run" ''
          if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
            echo "Usage: vkbasalt-run <command...>"
            echo ""
            echo "Launch a game with vkBasalt overlay enabled."
            echo "Sets ENABLE_VKBASALT=1 and LD_AUDIT for Wine Wayland input interposition."
            echo ""
            echo "Examples:"
            echo "  vkbasalt-run %command%      # Steam launch option"
            echo "  vkbasalt-run ./game          # Direct launch"
            echo ""
            echo "In-game controls:"
            echo "  ${cfg.overlayKey}    Open overlay UI (add/remove effects, save configs)"
            echo "  ${cfg.toggleKey}  Toggle effects on/off"
            echo ""
            echo "Config locations:"
            echo "  Defaults:      ~/.config/vkBasalt-overlay/vkBasalt.conf"
            echo "  Saved configs: ~/.config/vkBasalt-overlay/configs/"
            exit 0
          fi

          exec ${pkgs.vkbasalt-overlay}/bin/vkbasalt-run "$@"
        ''
      ))
    ];

    # vkBasalt overlay: user config (written to ~/.config/ via xdg.configFile)
    # The overlay's in-game UI manages per-game configs in ~/.config/vkBasalt-overlay/configs/
    xdg.configFile = {
      # Stable symlink for overlay UI shader manager (survives rebuilds)
      "vkBasalt-overlay/reshade".source = "${combinedShaders}/share/reshade";
      "vkBasalt-overlay/vkBasalt.conf".text = ''
        effects = ${cfg.effects}

        reshadeTexturePath = ${combinedShaders}/share/reshade/Textures
        reshadeIncludePath = ${combinedShaders}/share/reshade/Shaders
        depthCapture = off

        toggleKey = ${cfg.toggleKey}
        overlayKey = ${cfg.overlayKey}
        enableOnLaunch = ${if cfg.enableOnLaunch then "true" else "false"}
        autoApply = ${if cfg.autoApply then "true" else "false"}

        casSharpness = ${cfg.casSharpness}
      ''
      + lib.optionalString (cfg.extraConfig != "") ''

        ${cfg.extraConfig}
      '';
    };

    home.sessionVariables = {
      ENABLE_VKBASALT = lib.mkDefault "0";
    };
  };
}
