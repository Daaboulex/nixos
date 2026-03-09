{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Kate (Text Editor)
  # ============================================================================
  programs.kate = {
    enable = true;
    # package = pkgs.kdePackages.kate;
    # editor = {
    #   font = {
    #     family = "JetBrainsMono Nerd Font";
    #     pointSize = 11;
    #   };
    #   indent = {
    #     width = 2;
    #     replaceWithSpaces = true;
    #     showLines = true;
    #   };
    #   tabWidth = 2;
    #   inputMode = "normal";  # or "vi"
    #   brackets = {
    #     automaticallyAddClosing = true;
    #     highlightMatching = true;
    #   };
    # };
    # lsp.customServers = null;
    # dap.customServers = null;
  };

  # ============================================================================
  # Kate configFile — settings without native plasma-manager options
  # ============================================================================
  programs.plasma.configFile = {
    "katerc"."General" = {
      "Days Meta Infos" = lib.mkDefault 30;
      "Save Meta Infos" = lib.mkDefault true;
      "Show Full Path in Title" = lib.mkDefault false;
      "Show Menu Bar" = lib.mkDefault true;
      "Show Status Bar" = lib.mkDefault true;
      "Show Tab Bar" = lib.mkDefault true;
      "Show Url Nav Bar" = lib.mkDefault true;
    };

    "katerc"."KTextEditor Document" = {
      "Auto Detect Indent" = lib.mkDefault true;
      "Indentation Width" = lib.mkDefault 4;
      "Keep Extra Spaces" = lib.mkDefault false;
      ReplaceTabsDyn = lib.mkDefault false;
      "Tab Handling" = lib.mkDefault 2;
      "Tab Width" = lib.mkDefault 4;
    };

    "katerc"."KTextEditor Renderer" = {
      "Animate Bracket Matching" = lib.mkDefault false;
      "Show Indentation Lines" = lib.mkDefault true;
      "Text Font" = lib.mkDefault "Hack,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
    };

    "katerc"."KTextEditor View" = {
      "Auto Brackets" = lib.mkDefault false;
      "Bracket Match Preview" = lib.mkDefault false;
      "Chars To Enclose Selection" = lib.mkDefault "<>(){}[]'\"\`";
      "Input Mode" = lib.mkDefault 0;
    };

    "katerc"."filetree" = {
      listMode = lib.mkDefault false;
      middleClickToClose = lib.mkDefault false;
      shadingEnabled = lib.mkDefault true;
      showCloseButton = lib.mkDefault false;
      showFullPathOnRoots = lib.mkDefault false;
      showToolbar = lib.mkDefault true;
      sortRole = lib.mkDefault 0;
    };

    "katerc"."lspclient" = {
      AllowedServerCommandLines = lib.mkDefault "/run/current-system/sw/bin/nil";
      AutoHover = lib.mkDefault true;
      AutoImport = lib.mkDefault true;
      CompletionDocumentation = lib.mkDefault true;
      CompletionParens = lib.mkDefault true;
      Diagnostics = lib.mkDefault true;
      FormatOnSave = lib.mkDefault false;
      HighlightGoto = lib.mkDefault true;
      HighlightSymbol = lib.mkDefault true;
      IncrementalSync = lib.mkDefault false;
      InlayHints = lib.mkDefault false;
      Messages = lib.mkDefault true;
      ReferencesDeclaration = lib.mkDefault true;
      SemanticHighlighting = lib.mkDefault true;
      ShowCompletions = lib.mkDefault true;
      SignatureHelp = lib.mkDefault true;
      SymbolDetails = lib.mkDefault false;
      SymbolExpand = lib.mkDefault true;
      SymbolSort = lib.mkDefault false;
      SymbolTree = lib.mkDefault true;
      TypeFormatting = lib.mkDefault false;
    };
  };
}
