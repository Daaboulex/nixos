{ inputs, ... }:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    {
      # treefmt hook auto-wires to treefmt-nix config when both flakeModules are imported
      pre-commit.settings.hooks = {
        treefmt.enable = true;

        # Regenerate OPTIONS.md when module definitions change
        update-options-docs = {
          enable = true;
          name = "update-options-docs";
          entry = toString (
            pkgs.writeShellScript "update-options-docs" ''
              # Only run if any parts/ file is staged
              staged=$(${pkgs.git}/bin/git diff --cached --name-only -- 'parts/')
              if [ -z "$staged" ]; then
                exit 0
              fi

              echo "Module files changed — regenerating docs/OPTIONS.md..."
              result=$(${pkgs.nix}/bin/nix-build scripts/generate-docs.nix --no-out-link 2>/dev/null)
              if [ $? -ne 0 ]; then
                echo "WARNING: OPTIONS.md regeneration failed (nix-build error). Skipping."
                exit 0
              fi
              cp -f "$result" docs/OPTIONS.md
              ${pkgs.git}/bin/git add docs/OPTIONS.md
              echo "docs/OPTIONS.md updated and staged."
            ''
          );
          stages = [ "pre-commit" ];
          pass_filenames = false;
        };
      };

      devShells.default = config.pre-commit.devShell;
    };
}
