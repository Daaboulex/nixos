{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Kate (Text Editor) — native plasma-manager options where available
  # ============================================================================
  programs.kate = {
    enable = true;

    editor = {
      tabWidth = lib.mkDefault 4;

      indent = {
        width = lib.mkDefault 4;
        autodetect = lib.mkDefault true;
        keepExtraSpaces = lib.mkDefault false;
        replaceWithSpaces = lib.mkDefault false;
        showLines = lib.mkDefault true;
      };

      font = {
        family = lib.mkDefault "Hack";
        pointSize = lib.mkDefault 10;
      };

      inputMode = lib.mkDefault "normal";

      brackets = {
        automaticallyAddClosing = lib.mkDefault false;
        highlightMatching = lib.mkDefault true;
        flashMatching = lib.mkDefault false;
        characters = lib.mkDefault "<>(){}[]'\"`";
      };
    };

    # LSP server for Nix (nil)
    lsp.customServers = lib.mkDefault {
      nix = {
        command = [ "nil" ];
        highlightingModeRegex = "^Nix$";
      };
    };
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
