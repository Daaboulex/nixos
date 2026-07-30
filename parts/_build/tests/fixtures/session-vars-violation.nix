# Fixture: raw home.sessionVariables without the helper -- check-session-vars
# MUST fire on this. Never imported (lives under parts/_build/tests/fixtures).
{ lib, ... }:
{
  config = {
    home.sessionVariables = {
      FOO = lib.mkDefault "bar";
    };
  };
}
