# atuin — cross-machine shell history sync with full-text search.
{
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.home.atuin;
in
{
  options.myModules.home.atuin = {
    enable = lib.mkEnableOption "atuin shell history (replaces Ctrl+R with searchable, cross-machine history)";

    sync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable sync between machines. When false, atuin stores history
        locally only (~/.local/share/atuin/history.db). When true, syncs
        to a configured server (self-hosted or atuin.sh) with end-to-end
        encryption — server sees only ciphertext.
      '';
    };

    syncAddress = lib.mkOption {
      type = lib.types.str;
      default = "https://api.atuin.sh";
      description = ''
        Sync server address. Use "https://api.atuin.sh" for hosted
        (zero-knowledge E2E encrypted) or point at your own atuin-server
        instance (e.g., "http://ryzen-9950x3d:8888").
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;

      settings = {
        # Search behavior
        search_mode = "fuzzy";
        filter_mode = "global";
        style = "compact";
        inline_height = 20;
        show_preview = true;
        show_help = true;

        # History recording
        update_check = false;
        auto_sync = cfg.sync;
        sync_address = lib.mkIf cfg.sync cfg.syncAddress;
        sync_frequency = "5m";

        # Privacy: record context for better search, but keep it local
        # unless sync is explicitly enabled.
        history_filter = [
          "^export .*TOKEN"
          "^export .*SECRET"
          "^export .*PASSWORD"
          "^export .*KEY="
        ];

        # Store
        db_path = "~/.local/share/atuin/history.db";
        key_path = "~/.local/share/atuin/key";
        record_store_path = "~/.local/share/atuin/records.db";
      };
    };
  };
}
