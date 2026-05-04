# check-placement — file path ⟺ option scope path enforcement (STYLE.md §13a).
#
# Every parts/**/*.nix and home/modules/**/*.nix MUST declare options whose
# top-level scope matches its file path. Parser is grep+awk (no nix eval) so
# the hook fits the pre-commit budget.
#
# Invocation modes:
#   - With filename args: check each file (used by tests + manual auditing).
#   - No args: check every staged .nix file under parts/ + home/modules/.
#
# Exit: 0 pass, 1 on any mismatch (all violations printed, not just first).
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-placement";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    gawk
    gnused
    coreutils
    findutils
  ];
  text = ''
    # Pick the file list.
    if [ "$#" -gt 0 ]; then
      files=("$@")
    else
      mapfile -t staged < <(
        git diff --cached --name-only --diff-filter=ACMR -- 'parts/' 'home/modules/' \
          | grep -E '\.nix$' || true
      )
      if [ "''${#staged[@]}" -eq 0 ]; then
        exit 0
      fi
      files=("''${staged[@]}")
    fi

    failed=0

    # kebab-case → camelCase via GNU sed \U (uppercase-next-char).
    kebab_to_camel() {
      printf '%s' "$1" | sed -E 's/-([a-z])/\U\1/g'
    }

    exempt() {
      case "$1" in
        parts/hosts/*|parts/_build/*) return 0 ;;
        home/hosts/*|home/lib/*)      return 0 ;;
        */flake-module.nix|flake.nix) return 0 ;;
      esac
      local base
      base=$(basename "$1")
      case "$base" in _*.nix) return 0 ;; esac
      return 1
    }

    for f in "''${files[@]}"; do
      exempt "$f" && continue
      [ -f "$f" ] || continue

      # Classify by file path.
      expected_scope=""
      expected_leaf=""
      kind=""
      case "$f" in
        parts/*/*.nix)
          expected_scope=$(basename "$(dirname "$f")")
          expected_leaf=$(kebab_to_camel "$(basename "$f" .nix)")
          kind=parts_nested
          ;;
        parts/*.nix)
          expected_scope=$(basename "$f" .nix)
          kind=parts_top
          ;;
        home/modules/*/default.nix)
          expected_scope=home
          expected_leaf=$(basename "$(dirname "$f")")
          kind=home_default
          ;;
        home/modules/*/*.nix)
          expected_scope=home
          umbrella=$(basename "$(dirname "$f")")
          sub=$(kebab_to_camel "$(basename "$f" .nix)")
          expected_leaf="$umbrella.$sub"
          kind=home_umbrella_sub
          ;;
        *) continue ;;
      esac

      # Detect actual scope + leaf.
      actual_scope=""
      actual_leaf=""

      if [ "$kind" = "home_default" ] && grep -q 'lib/mkSimplePackage\.nix' "$f" 2>/dev/null; then
        # mkSimplePackage wrapper: name arg is authoritative.
        name_arg=$(grep -Eo 'name[[:space:]]*=[[:space:]]*"[^"]+"' "$f" 2>/dev/null \
                   | head -1 | awk -F'"' '{print $2}' || true)
        if [ -z "$name_arg" ]; then
          echo "check-placement: $f"
          echo "  could not parse mkSimplePackage name argument"
          echo "  fix: ensure the wrapper sets \`name = \"<dirname>\"\`"
          echo "  reference: docs/STYLE.md §13a"
          failed=1
          continue
        fi
        actual_scope=home
        actual_leaf="$name_arg"
      else
        # Scan for first options.myModules.<path>.
        # `|| true` is required: grep returns 1 when no match, which under
        # `set -euo pipefail` would kill the script.
        path=$(grep -Eho 'options\.myModules\.[A-Za-z][A-Za-z0-9_.-]*' "$f" 2>/dev/null \
               | head -1 | sed 's/^options\.myModules\.//' || true)
        if [ -z "$path" ]; then
          # No option declaration found → pure helper/package spec. Exempt.
          continue
        fi
        actual_scope=$(printf '%s' "$path" | cut -d. -f1)
        actual_leaf=$(printf '%s' "$path" | cut -d. -f2- -s || true)
      fi

      # Compare.
      #
      # Enforcement model:
      #   - parts/<dir>/<name>.nix : scope must equal dir (leaf free — upstream
      #     allows multiple files to share one namespace, e.g. services.networking.*).
      #   - parts/<name>.nix       : scope must equal filename stem.
      #   - home/modules/<n>/default.nix : leaf must equal dirname.
      #   - home/modules/<u>/<sub>.nix   : first-leaf must equal umbrella
      #     dirname AND the sub-scope must appear deeper in the option path
      #     (STYLE.md §1.1.4 umbrella nesting).
      scope_ok=1
      leaf_ok=1
      [ "$actual_scope" = "$expected_scope" ] || scope_ok=0

      case "$kind" in
        parts_top|parts_nested)
          # Scope match is the only rule for parts/* — leaf naming is STYLE §2.1
          # (camelCase), enforced elsewhere; one scope may span multiple files.
          :
          ;;
        home_default)
          first_leaf=$(printf '%s' "$actual_leaf" | cut -d. -f1)
          [ "$first_leaf" = "$expected_leaf" ] || leaf_ok=0
          ;;
        home_umbrella_sub)
          expected_u=$(printf '%s' "$expected_leaf" | cut -d. -f1)
          expected_s=$(printf '%s' "$expected_leaf" | cut -d. -f2)
          first_leaf=$(printf '%s' "$actual_leaf" | cut -d. -f1)
          if [ "$first_leaf" != "$expected_u" ]; then
            leaf_ok=0
          elif [ -n "$expected_s" ] && ! printf '%s' "$actual_leaf" \
               | grep -qE "(^|\.)$expected_s(\.|\$)"; then
            leaf_ok=0
          fi
          ;;
      esac

      if [ "$scope_ok" -eq 0 ] || [ "$leaf_ok" -eq 0 ]; then
        echo "check-placement: $f"
        if [ -n "$expected_leaf" ]; then
          echo "  expected scope: myModules.$expected_scope.$expected_leaf"
        else
          echo "  expected scope: myModules.$expected_scope"
        fi
        if [ -n "$actual_leaf" ]; then
          echo "  actual scope:   myModules.$actual_scope.$actual_leaf"
        else
          echo "  actual scope:   myModules.$actual_scope"
        fi
        case "$kind" in
          parts_nested|parts_top)
            echo "  fix: either move the file to parts/$actual_scope/ or change the option path to myModules.$expected_scope.*"
            ;;
          home_default)
            echo "  fix: either rename the home/modules/ directory to match the option leaf, or change the option path to myModules.home.$expected_leaf.*"
            ;;
          home_umbrella_sub)
            echo "  fix: sub-module must declare options under myModules.home.$expected_u.* and live in the umbrella directory (imported from <u>/default.nix)"
            ;;
        esac
        echo "  reference: docs/STYLE.md §13a"
        failed=1
      fi
    done

    if [ "$failed" -ne 0 ]; then
      echo ""
      echo "check-placement failed. See docs/STYLE.md §13a (Placement rule)."
      exit 1
    fi
    exit 0
  '';
}
