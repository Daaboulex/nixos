{ inputs, ... }: {
  flake.nixosModules.tools-llm-prep = { config, lib, pkgs, ... }:
    let
      cfgTools = config.myModules.tools;

      # ════════════════════════════════════════════════════════════════════════
      # llm-prep — Combine project files into a single context for LLMs
      # ════════════════════════════════════════════════════════════════════════
      llm-prep = pkgs.writeShellApplication {
        name = "llm-prep";
        runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.findutils pkgs.tree ];
        text = ''#!${pkgs.bash}/bin/bash
          # Combines project files into a single context for LLMs
          # Usage: llm-prep [directory] [-o output.txt]
          set -euo pipefail

          TARGET_DIR="''${1:-.}"
          OUTPUT_FILE="context.txt"

          if [[ "''${2:-}" == "-o" ]]; then
            OUTPUT_FILE="''${3:-context.txt}"
          fi

          echo "Generating context from $TARGET_DIR into $OUTPUT_FILE..."

          {
            echo "Project Structure:"
            ${pkgs.tree}/bin/tree "$TARGET_DIR" -I "result|node_modules|.git" --dirsfirst
            echo -e "\nFile Contents:\n"

            ${pkgs.findutils}/bin/find "$TARGET_DIR" -maxdepth 3 -type f \
              -not -path '*/.*' \
              -not -path '*/result/*' \
              -not -name "*.lock" \
              -not -name "*.png" \
              -not -name "*.jpg" \
              -print0 | while IFS= read -r -d "" file; do
                echo "=== $file ==="
                cat "$file"
                echo -e "\n"
            done
          } > "$OUTPUT_FILE"

          echo "Done: $OUTPUT_FILE"
        '';
      };
    in {
      options.myModules.tools.llmPrep.enable = lib.mkEnableOption "llm-prep";

      config = lib.mkIf cfgTools.llmPrep.enable {
        environment.systemPackages = [ llm-prep ];
      };
    };
}
