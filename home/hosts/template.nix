{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # Host-Specific Home Configuration Template
  # ============================================================================
  # Copy to home/hosts/<hostname>/default.nix and customise.
  # For a comprehensive reference of all toggles, see home/hosts/ryzen-9950x3d/
  # or generate a template: nix-build scripts/generate-hm-template.nix --no-out-link

  # Git credentials (required)
  programs.git.settings.user = {
    name = "<username>";
    email = "<email>";
  };

  # Module toggles — override defaults per host
  # programs.btop.enable = true;
  # programs.htop.enable = false;
  # programs.vscode.enable = true;
  # programs.ghostwriter.enable = false;
  # programs.elisa.enable = false;
  # services.easyeffects.enable = false;

  # Flatpak packages
  # services.flatpak.packages = [
  #   "org.example.App"
  # ];
}
