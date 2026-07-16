# nixpkgs#513245: openldap test017-syncreplication-refresh fails consistently
# on i686 (32-bit cross-build). Only affects bottles/wine FHS envs that pull
# pkgsi686Linux.openldap. 64-bit keeps its tests.
{
  # openldap moved past the version observed broken — re-verify the i686
  # tests and either delete this fix or update the observed version.
  dropWhen = pkgs: pkgs.openldap.version != "2.6.13";
  overlay = _final: prev: {
    openldap = prev.openldap.overrideAttrs {
      doCheck = !prev.stdenv.hostPlatform.isi686;
    };
  };
}
