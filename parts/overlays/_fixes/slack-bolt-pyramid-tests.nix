# setuptools >= 82 removed pkg_resources; slack-bolt's pyramid adapter test
# imports pyramid -> pkg_resources and dies at pytest collection. nixpkgs
# only ignores the bottle adapter tests. Breaks hermes-agent's python env.
{
  # Upstream added the pyramid ignore itself, or slack-bolt moved past the
  # version observed broken — re-verify, then delete or re-observe.
  dropWhen =
    pkgs:
    builtins.elem "tests/adapter_tests/pyramid/" pkgs.python3Packages.slack-bolt.disabledTestPaths
    || pkgs.python3Packages.slack-bolt.version != "1.29.0";
  overlay = _final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_pyFinal: pyPrev: {
        slack-bolt = pyPrev.slack-bolt.overridePythonAttrs (old: {
          disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
            "tests/adapter_tests/pyramid/"
          ];
        });
      })
    ];
  };
}
