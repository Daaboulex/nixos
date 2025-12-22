{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # VSCodium - Open source VS Code
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  programs.vscode = {
    package = pkgs.vscodium;
    
    # Default profile configuration (new HM format)
    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      
      # Extensions from nixpkgs
      extensions = with pkgs.vscode-extensions; [
        # Nix support
        jnoortheen.nix-ide
        
        # General development
        #eamodio.gitlens
        #editorconfig.editorconfig
        
        # Theme
        catppuccin.catppuccin-vsc
        catppuccin.catppuccin-vsc-icons
        
        # Python (if needed)
        #ms-python.python
        
        # Rust (if needed)
        #rust-lang.rust-analyzer
      ];
      
      # User settings (settings.json)
      userSettings = {
        # Editor
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace'";
        "editor.fontSize" = 14;
        "editor.tabSize" = 2;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "boundary";
        "editor.cursorBlinking" = "smooth";
        "editor.smoothScrolling" = true;
        "editor.bracketPairColorization.enabled" = true;
        
        # Workbench
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "catppuccin-mocha";
        "workbench.startupEditor" = "none";
        
        # Files
        "files.autoSave" = "afterDelay";
        "files.autoSaveDelay" = 1000;
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;
        
        # Terminal
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
        "terminal.integrated.fontSize" = 13;
        
        # Nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        
        # Git
        "git.autofetch" = true;
        "git.confirmSync" = false;
        
        # Telemetry
        "telemetry.telemetryLevel" = "off";
      };
    };
  };
}
