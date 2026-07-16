# check-pin-behind-checkout -- flake input pins vs their repos/ workbenches.
#
# Wraps check-pin-behind-checkout.py. Fails when a DIRECT input's locked rev
# is behind (or diverged from) the committed HEAD of its local checkout under
# repos/ -- the "pushed the fix, forgot `nix flake update`" gap that deploys
# stale code. Workbench-behind-pin is a printed notice, never a failure
# (blocking there would couple unrelated commits to a pull). Machines without
# repos/ or a given checkout skip: no workbench, no possible drift. Local git
# only, no network. The sandboxed self-test lives in tests.nix with fixture
# repos, because `nix flake check` cannot see the gitignored repos/.
#
# Exit: 0 clean or notices only, 1 on any pin-behind or diverged input.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-pin-behind-checkout";
  runtimeInputs = with pkgs; [
    python313
    git
  ];
  text = ''
    exec python3 ${./check-pin-behind-checkout.py} "$@"
  '';
}
