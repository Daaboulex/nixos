# deploy-readiness — every bare-metal host (identified by having a
# hardware-configuration.nix) carries the full install contract: a
# disko.nix that is inert at runtime (disko.enableConfig = false), wired
# into its flake-module.nix, and addressed by /dev/disk/by-path so a
# replacement disk resolves. The site-escrow half of the contract (host
# identity, /etc/secrets seed) is enforced at runtime by nrb --install,
# because the private site registry lives outside the flake source.
# Single source for the pre-commit hook (staged-gated) and the flake
# check (--all).
#
# Invocation: (none)=gate on staged parts/hosts files · --all=whole tree.
{ pkgs }:
pkgs.writeShellApplication {
  name = "deploy-readiness";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    coreutils
  ];
  text = ''
    if [ "''${1:-}" != "--all" ]; then
      staged=$(git diff --cached --name-only -- 'parts/hosts/')
      [ -z "$staged" ] && exit 0
    fi

    echo "Checking the deploy contract for bare-metal hosts..."
    failed=0
    for hostdir in parts/hosts/*/; do
      host=$(basename "$hostdir")
      # Not bare-metal (e.g. the AVF VM) -> no install contract required.
      [ -f "$hostdir/hardware-configuration.nix" ] || continue
      if [ ! -f "$hostdir/disko.nix" ]; then
        echo "FAIL $host: no disko.nix (install-time disk ground truth missing)"
        failed=1
        continue
      fi
      if ! grep -q 'disko.enableConfig = false' "$hostdir/disko.nix"; then
        echo "FAIL $host: disko.nix must set disko.enableConfig = false (runtime mounts have their own owners)"
        failed=1
      fi
      if ! grep -q 'disko.nix' "$hostdir/flake-module.nix"; then
        echo "FAIL $host: flake-module.nix does not import ./disko.nix (nixos-anywhere cannot see the layout)"
        failed=1
      fi
      if ! grep -q '/dev/disk/by-path/' "$hostdir/disko.nix"; then
        echo "FAIL $host: disko devices must use /dev/disk/by-path (by-uuid/by-id do not exist on a replacement disk)"
        failed=1
      fi
      # Every subvolume the runtime mounts must exist in the install
      # layout, or a reinstall boots into missing mounts. (disko may
      # create MORE -- e.g. @persist staged for impermanence.) Process
      # substitution, not a pipe: a piped while-loop is a subshell and
      # would silently drop failed=1 (fail-open).
      while read -r sv; do
        [ -n "$sv" ] || continue
        if ! grep -q "\"$sv\"" "$hostdir/disko.nix"; then
          echo "FAIL $host: runtime mounts subvolume $sv but disko.nix does not create it (a reinstall would not boot)"
          failed=1
        fi
      done < <(grep -ohE 'subvol=@[A-Za-z0-9_-]*' "$hostdir/hardware-configuration.nix" | sed 's/subvol=//' | sort -u)
    done
    [ "$failed" = 0 ] && echo "deploy contract OK"
    exit "$failed"
  '';
}
