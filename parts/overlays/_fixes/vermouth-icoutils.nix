# nixpkgs' vermouth wraps only umu-launcher onto PATH, so IconExtractor's
# QStandardPaths::findExecutable("wrestool") finds nothing and .exe icon
# extraction degrades to no icon with no error. Upstream ships icoutils as a
# recommended runtime dependency (Arch optdepends, RPM Recommends).
{
  # Upstream put icoutils on vermouth's own wrapper PATH — delete this file.
  dropWhen = pkgs: builtins.any (pkgs.lib.hasInfix "icoutils") (pkgs.vermouth.qtWrapperArgs or [ ]);
  overlay = final: prev: {
    vermouth = prev.vermouth.overrideAttrs (old: {
      qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
        "--prefix"
        "PATH"
        ":"
        "${final.icoutils}/bin"
      ];
    });
  };
}
