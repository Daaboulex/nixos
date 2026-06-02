{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";

        # Nix
        programs.nixfmt.enable = true;
        programs.deadnix = {
          enable = true;
          # Don't flag unused args in lambda attr patterns — flake-parts
          # modules destructure { config, self', inputs', pkgs, … }: and
          # rely on downstream code using a subset.
          no-lambda-pattern-names = true;
          # Don't flag bindings intentionally prefixed with underscore
          # (upcoming `_foo` sentinels; standard nixpkgs convention).
          no-underscore = true;
        };
        programs.statix.enable = true;

        # Shell
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;

        # JSON, YAML, Markdown
        programs.prettier = {
          enable = true;
          package = pkgs.prettier; # nodePackages removed from nixpkgs; use top-level
          includes = [
            "*.json"
            "*.yaml"
            "*.yml"
            "*.md"
          ];
          excludes = [
            "flake.lock"
            ".ai-context/**"
            "repos/**"
            # Internal audit log — full of technical tokens (x86_64, regexes,
            # option paths) that prettier's markdown emphasis rules corrupt.
            "AUDIT.md"
          ];
        };
      };
    };
}
