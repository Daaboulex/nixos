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
    # Owner identity -- single source for every host (was re-declared per-host,
    # via two divergent option paths). A host needing a different identity
    # overrides userName/userEmail.
    userName = lib.mkOption {
      type = lib.types.str;
      default = "Daaboulex";
      description = "Git author/committer name.";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "39669593+Daaboulex@users.noreply.github.com";
      description = "Git author/committer email.";
    };
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.git = myLib.mergeSettings {
      # Owner identity (userName/userEmail) folded in as the single source.
      # recursiveUpdate -- not // -- merges the theme colors so settings.user,
      # settings.core, and settings.color all survive together (a shallow // would
      # drop core/user whenever a theme is active).
      defaults =
        lib.recursiveUpdate
          {
            enable = true;
            lfs.enable = lib.mkDefault true;
            ignores = [
              ".crush/"
              "**/.claude/settings.local.json"
            ];
            settings = {
              user = {
                name = cfg.userName;
                email = cfg.userEmail;
              };
              core = {
                # Syncthing compatibility: prevent phantom diffs from ctime/stat changes.
                # trustctime=false ignores ctime (git still checks mtime+size+content);
                # checkStat=minimal checks only size + whole-second mtime.
                trustctime = false;
                checkStat = "minimal";
              };
            };
          }
          (
            lib.optionalAttrs hasTheme {
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
            }
          );
      overrides = cfg.settings;
    };

    programs.gh = {
      enable = lib.mkDefault true;
      gitCredentialHelper.enable = lib.mkDefault true;
    };
  };
}
