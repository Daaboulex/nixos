{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      # Exclude auto-generated template files (contain raw option defaults, not valid Nix)
      settings.global.excludes = [
        "docs/*.example"
      ];

      # Nix
      programs.nixfmt.enable = true;
      programs.deadnix = {
        enable = true;
        no-lambda-pattern-names = true;
      };
      programs.statix.enable = true;

      # Shell
      programs.shfmt.enable = true;
      programs.shellcheck.enable = true;
    };
  };
}
