{ inputs, ... }: {
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = { ... }: {
    treefmt = {
      projectRootFile = "flake.nix";

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
