# mkExhaustivenessCheck — factory for "every host must reference every
# module in dir X" gates.
#
# Consumer: nixos-exhaustiveness (see ./nixos-exhaustiveness.nix) —
# parts/hosts/*/flake-module.nix must reference every parts/**/*.nix module
# (catches "added a module, forgot to wire it up").
#
# Invocation modes of the generated binary:
#   - (none) : gate on staged files only (pre-commit; exits 0 when nothing
#              relevant is staged).
#   - --all  : unconditional scan of the working tree (flake check / CI),
#              where no git index exists.

{ pkgs }:

{
  # Human-visible label ("HM", "NixOS").
  kind,
  # Name of the generated binary / hook.
  name,
  # Glob (bash-style) of host files to audit. Each is expected to be a
  # plain .nix file where "grep" can find the expected pattern.
  hostGlob,
  # Command producing the newline-separated list of module *names* to
  # enforce. Keep it shellable; it runs inside the hook.
  moduleListCmd,
  # Printf-style pattern the host file must contain for each module name.
  # `%s` is replaced with the module name via bash parameter expansion.
  expectedPattern,
  # Remediation hint printed on failure.
  fixHint,
  # Staged-file filter — skip early if no files under this path changed.
  stagedFilter,
}:

pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = with pkgs; [
    git
    findutils
    gnugrep
    coreutils
  ];
  text = ''
    if [ "''${1:-}" != "--all" ]; then
      staged=$(git diff --cached --name-only -- ${stagedFilter})
      [ -z "$staged" ] && exit 0
    fi

    echo "Checking ${kind} module exhaustiveness..."
    failed=0

    modules=$(${moduleListCmd})

    # shellcheck disable=SC2066
    for host_cfg in ${hostGlob}; do
      hostname=$(basename "$(dirname "$host_cfg")")

      # Extract the per-host exclude list from a magic comment block at
      # the top of the host file:
      #
      #   # exhaustiveness-exclude:
      #   #   gaming-steam gaming-rocksmith
      #   #   vfio-session-gpu vfio-device-binding
      #
      # Comment block ends at the first non-comment or blank line.
      excludes=$(awk '
        /^[[:space:]]*#[[:space:]]*exhaustiveness-exclude:/ { in_block = 1; next }
        in_block {
          if (/^[[:space:]]*#/) {
            # Strip leading "# " and collapse whitespace
            line = $0
            sub(/^[[:space:]]*#[[:space:]]*/, "", line)
            print line
          } else {
            in_block = 0
          }
        }
      ' "$host_cfg" | tr -s '[:space:]' '\n' | grep -v '^$' || true)

      for mod in $modules; do
        # Skip if in exclude list
        if printf '%s\n' "$excludes" | grep -qxF "$mod"; then
          continue
        fi
        expected=$(printf '${expectedPattern}' "$mod")
        if ! grep -qE "$expected" "$host_cfg" 2>/dev/null; then
          echo "MISSING: $hostname is missing $expected"
          failed=1
        fi
      done
    done

    if [ "$failed" -ne 0 ]; then
      echo ""
      echo "${fixHint}"
      exit 1
    fi
    echo "All ${kind} host configs are exhaustive."
  '';
}
