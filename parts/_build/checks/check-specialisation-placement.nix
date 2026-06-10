# check-specialisation-placement — specialisations live in
# parts/hosts/<host>/specialisations/<name>.nix, never inline in the host
# default.nix. The ONLY specialisation assignment a host default.nix may
# contain is the myLib.mkSpecialisations call wiring that folder.
#
# Invocation modes:
#   - With filename args: check each file (tests + manual auditing).
#   - No args: check every parts/hosts/*/default.nix under the cwd.
#
# Exit: 0 pass, 1 on any inline specialisation (all violations printed).
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-specialisation-placement";
  runtimeInputs = with pkgs; [
    gnugrep
    gnused
    coreutils
  ];
  # gnused: comment-stripping pass before the specialisation grep.
  text = ''
    if [ "$#" -gt 0 ]; then
      files=("$@")
    else
      mapfile -t files < <(ls parts/hosts/*/default.nix 2>/dev/null || true)
      [ "''${#files[@]}" -eq 0 ] && exit 0
    fi

    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # Comments stripped first (sed keeps line numbers aligned).
      # Inline form: `specialisation.<name>.` attr paths (a leading dot means a
      # READ like config.specialisation.* — allowed).
      inline=$(sed 's/#.*$//' "$f" | grep -nE '(^|[^.a-zA-Z])specialisation\.[A-Za-z0-9_-]+' || true)
      # Assignment form: `specialisation = …` with anything but the
      # mkSpecialisations wiring call.
      assigned=$(sed 's/#.*$//' "$f" | grep -nE '(^|[^.a-zA-Z])specialisation[[:space:]]*=' \
                 | grep -vE 'mkSpecialisations' || true)
      if [ -n "$inline" ] || [ -n "$assigned" ]; then
        echo "check-specialisation-placement: $f"
        [ -n "$inline" ] && printf '  inline: %s\n' "$inline"
        [ -n "$assigned" ] && printf '  assign: %s\n' "$assigned"
        echo "  fix: move each spec to specialisations/<name>.nix and wire the folder with"
        echo "       \`specialisation = myLib.mkSpecialisations { dir = ./specialisations; };\`"
        failed=1
      fi
    done
    exit "$failed"
  '';
}
