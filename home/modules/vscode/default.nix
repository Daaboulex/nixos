{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # VSCodium - Open source VS Code
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  programs.vscode = {
    package = pkgs.vscodium;

    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ];

      userSettings = lib.mkDefault {
        # Nix LSP
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";

        # Telemetry
        "telemetry.telemetryLevel" = "off";
      };
    };
  };
}
