# nix-github-token — authenticated GitHub fetches for user-run nix commands.
#
# The system-side /etc/nix/github-token is root-0600 and nix's !include
# skips unreadable files silently, so user-run flake operations fall back
# to the 60/hour unauthenticated GitHub API limit and rate-limit on any
# lock refresh that re-fetches inputs. This mirrors the token from the gh
# CLI into the user nix.conf include path at activation; !include
# tolerates absence, so a machine without gh auth just stays
# unauthenticated instead of failing.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.nix-github-token;
in
{
  options.myModules.home.nix-github-token = {
    enable = lib.mkEnableOption "GitHub access token for user-run nix fetches (mirrored from `gh auth token` at activation)";
  };

  config = lib.mkIf cfg.enable {
    # Relative !include resolves against the including file's directory.
    xdg.configFile."nix/nix.conf".text = ''
      !include github-token
    '';

    home.activation.nixGithubToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      token=$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true)
      if [ -n "$token" ]; then
        mkdir -p "${config.xdg.configHome}/nix"
        (
          umask 077
          printf 'access-tokens = github.com=%s\n' "$token" \
            > "${config.xdg.configHome}/nix/github-token"
        )
      else
        # gh auth gone: remove any previously mirrored token — a stale
        # (possibly revoked) token fails harder than no token.
        rm -f "${config.xdg.configHome}/nix/github-token"
      fi
    '';
  };
}
