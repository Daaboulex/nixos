# placement-violation — synthetic fixture for check-placement-test.
#
# Declares options.myModules.services.foo while the test places this file
# under parts/security/foo.nix — so the hook's scope-match rule MUST fire
# (expected scope: myModules.security, actual: myModules.services).
#
# NOT auto-imported (lives under parts/_build/tests/fixtures/ which is
# exempt from the hook). Used only by the check-placement-test derivation.
{
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.services.foo;
in
{
  options.myModules.services.foo = {
    enable = lib.mkEnableOption "synthetic placement-violation fixture";
  };

  config = lib.mkIf cfg.enable { };
}
