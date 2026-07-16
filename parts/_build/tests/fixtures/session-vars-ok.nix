# Fixture: session vars via the helper -- check-session-vars MUST pass this.
# Never imported (lives under parts/_build/tests/fixtures).
{ myLib, ... }:
{
  config = myLib.mkSessionVars { FOO = "bar"; };
}
