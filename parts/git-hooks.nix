{ inputs, ... }: {
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem = { config, ... }: {
    # treefmt hook auto-wires to treefmt-nix config when both flakeModules are imported
    pre-commit.settings.hooks = {
      treefmt.enable = true;
    };

    devShells.default = config.pre-commit.devShell;
  };
}
