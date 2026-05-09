# git — git version control with GitHub CLI and delta pager integration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.git;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.git = {
    enable = lib.mkEnableOption "Git version control with GitHub CLI";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # User credentials set per-host in home/hosts/<hostname>/default.nix
    programs.git = myLib.mergeSettings {
      defaults = {
        enable = true;
        lfs.enable = lib.mkDefault true;
        ignores = [ ".crush/" ];
        extraConfig.core = {
          # Syncthing compatibility — prevent phantom diffs from ctime/stat changes.
          # Syncthing preserves mtime but always updates ctime on delivery.
          # trustctime=false: ignore ctime mismatches (safe — git still checks mtime+size+content)
          # checkStat=minimal: only check size + whole-second mtime (skips sub-second, inode, uid/gid)
          # Both are standard on network/sync filesystems. git add/commit still content-hash.
          trustctime = false;
          checkStat = "minimal";
        };
      }
      // lib.optionalAttrs hasTheme {
        settings.color = {
          ui = "auto";
          branch = {
            current = "${c.blue} bold";
            local = c.blue;
            remote = c.green;
          };
          status = {
            added = c.green;
            changed = c.orange;
            untracked = c.red;
          };
          diff = {
            meta = "${c.foreground-dim} bold";
            frag = "${c.blue} bold";
            old = c.red;
            new = c.green;
          };
        };
      };
      overrides = cfg.settings;
    };

    programs.gh = {
      enable = lib.mkDefault true;
      gitCredentialHelper.enable = lib.mkDefault true;
    };
  };
}
