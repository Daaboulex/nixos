# starship — cross-shell prompt with theme-aware styling.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.starship;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.starship = {
    enable = lib.mkEnableOption "Starship cross-shell prompt";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.starship = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault true;
        settings = {
          add_newline = lib.mkDefault true;

          # Classic "user@host" format with modern styling
          username = {
            show_always = lib.mkDefault true;
            style_user = lib.mkDefault "bold blue";
            format = lib.mkDefault "[$user]($style)@";
          };

          hostname = {
            ssh_only = lib.mkDefault false;
            style = lib.mkDefault "bold blue";
            format = lib.mkDefault "[$hostname]($style) ";
          };
        }
        // lib.optionalAttrs hasTheme {
          palette = "breeze-dark";
          palettes."breeze-dark" = {
            inherit (c)
              blue
              red
              green
              orange
              purple
              ;
            fg = c.foreground;
            fg-dim = c.foreground-dim;
            bg = c.background;
          };

          # Module styles — reference palette color names above
          character = {
            success_symbol = "[>](bold green)";
            error_symbol = "[>](bold red)";
          };
          directory = {
            style = "bold blue";
            truncation_length = 3;
          };
          git_branch.style = "bold purple";
          git_status.style = "bold orange";
          nix_shell = {
            style = "bold blue";
            symbol = " ";
            format = "via [$symbol$state( \\($name\\))]($style) ";
          };
          cmd_duration = {
            style = "fg-dim";
            min_time = 2000;
          };
          python.style = "bold green";
          nodejs.style = "bold green";
          rust.style = "bold orange";
          package.style = "bold orange";

          # Disable cloud provider prompts — they pollute the prompt
          # when gcloud/azure/aws configs exist on disk
          gcloud.disabled = true;
          aws.disabled = true;
          azure.disabled = true;
        };
      };
      overrides = cfg.settings;
    };
  };
}
