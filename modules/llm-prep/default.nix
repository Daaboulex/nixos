# LLM Prep - prepare directory contents for LLM context
{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.tools.llmPrep;

  llm-prep = pkgs.writeShellApplication {
    name = "llm-prep";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.findutils pkgs.tree ];
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      DEFAULT_OUTPUT_FILENAME="llm_prepared_context.txt"
      EXTENSIONS_TO_COPY="nix sh md"
      FILE_SEPARATOR="--- END OF FILE --- START OF FILE "
      TREE_EXCLUDE_PATTERN=".git"
      INPUT_DIR=""; OUTPUT_FILE="";
      usage(){ cat <<EOF
      Usage: $(basename "$0") -i <input_directory> [-o <output_file>] [-e <extensions>]
      EOF
      exit 1; }
      while getopts "i:o:e:h" opt; do case $opt in i) INPUT_DIR="$OPTARG";; o) OUTPUT_FILE="$OPTARG";; e) EXTENSIONS_TO_COPY="$OPTARG";; h) usage;; *) usage;; esac; done
      shift $((OPTIND-1))
      [ -z "$INPUT_DIR" ] && usage
      [ ! -d "$INPUT_DIR" ] && exit 1
      INPUT_DIR="$(readlink -m "$INPUT_DIR")"
      if [ -z "$OUTPUT_FILE" ]; then OUTPUT_FILE="$INPUT_DIR/$DEFAULT_OUTPUT_FILENAME"; elif [[ "$OUTPUT_FILE" != /* ]]; then OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"; fi
      output_basename=$(basename "$OUTPUT_FILE")
      mkdir -p "$(dirname "$OUTPUT_FILE")"; echo -n "" > "$OUTPUT_FILE"
      {
        echo "--- DIRECTORY STRUCTURE ---"; echo "";
        tree -I "$TREE_EXCLUDE_PATTERN|$output_basename" --noreport "$INPUT_DIR" || true; echo "";
        echo "--- FILE CONTENTS ---"; echo "";
      } >> "$OUTPUT_FILE"
      find_args=("$INPUT_DIR" -type f)
      if [[ "$EXTENSIONS_TO_COPY" != "all" ]]; then
      find_ext_args=()
      for ext in $EXTENSIONS_TO_COPY; do
        clean_ext="''${ext#.}"
        if [ ''${#find_ext_args[@]} -eq 0 ]; then
          find_ext_args=(-name "*.$clean_ext")
        else
          find_ext_args+=(-o -name "*.$clean_ext")
        fi
      done
      if [ ''${#find_ext_args[@]} -gt 0 ]; then
        find_args+=(\( "''${find_ext_args[@]}" \))
      else
        find_args+=(-false)
      fi
      fi
      first_file=true
      find "''${find_args[@]}" -not -path "$OUTPUT_FILE" -not -path "*/.git/*" -not -name "flake.lock" -print0 | while IFS= read -d $'\0' -r source_file; do
        relative_path="''${source_file#"$INPUT_DIR"/}"; clean_name="''${relative_path//\\//-}";
        if [ "$first_file" = true ]; then echo "--- START OF FILE ''${clean_name} ---" >> "$OUTPUT_FILE"; first_file=false; else { echo ""; echo -n "''${FILE_SEPARATOR}"; echo "''${clean_name} ---"; } >> "$OUTPUT_FILE"; fi
        cat "$source_file" >> "$OUTPUT_FILE" || true
      done
    '';
  };
in {
  options.myModules.tools.llmPrep = {
    enable = lib.mkEnableOption "llm-prep tool for preparing LLM context";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ llm-prep ];
  };
}