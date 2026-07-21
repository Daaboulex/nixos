#!/usr/bin/env bash
# gates excludes VM (KVM), host-IFD, and pre-commit (live remote) targets; eval takes ryzen etc-only (VFIO IFD is in no public cache; the full ryzen toplevel is a local pre-commit check).
set -euo pipefail

mode="${1:?usage: ci-checks.sh eval|gates}"
stub=(--override-input site path:./ci/site-stub)

case "$mode" in
eval)
  failed=0
  printf '  %-25s ' "ryzen-9950x3d"
  if output=$(nix eval ".#nixosConfigurations.ryzen-9950x3d.config.system.build.etc.drvPath" "${stub[@]}" 2>&1); then
    echo "OK (etc)"
  else
    echo "FAIL"
    echo "$output" | tail -5 | sed 's/^/    /'
    failed=1
  fi
  for host in macbook-pro-9-2 pixel-9-pro; do
    printf '  %-25s ' "$host"
    if output=$(nix eval ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" "${stub[@]}" 2>&1); then
      echo "OK"
    else
      echo "FAIL"
      echo "$output" | tail -5 | sed 's/^/    /'
      failed=1
    fi
  done

  assert_expr='as: let bad = builtins.filter (a: !a.assertion) as; in if bad == [ ] then "ok" else throw (builtins.concatStringsSep " | " (map (a: a.message) bad))'
  printf '  %-25s ' "ryzen assertions"
  if output=$(nix eval --raw ".#nixosConfigurations.ryzen-9950x3d.config.assertions" --apply "$assert_expr" "${stub[@]}" 2>&1); then
    echo "OK"
  else
    echo "FAIL"
    echo "$output" | tail -5 | sed 's/^/    /'
    failed=1
  fi
  if specs=$(nix eval --raw ".#nixosConfigurations.ryzen-9950x3d.config.specialisation" --apply 'ss: builtins.concatStringsSep " " (builtins.attrNames ss)' "${stub[@]}" 2>/dev/null); then
    for spec in $specs; do
      printf '  %-25s ' "ryzen spec:$spec"
      if output=$(nix eval --raw ".#nixosConfigurations.ryzen-9950x3d.config.specialisation.$spec.configuration.assertions" --apply "$assert_expr" "${stub[@]}" 2>&1); then
        echo "OK"
      else
        echo "FAIL"
        echo "$output" | tail -5 | sed 's/^/    /'
        failed=1
      fi
    done
  else
    echo "  ryzen specialisations     FAIL (enumeration)"
    failed=1
  fi
  exit "$failed"
  ;;
gates)
  exec nix build --no-link --print-build-logs "${stub[@]}" \
    .#checks.x86_64-linux.treefmt \
    .#checks.x86_64-linux.check-placement \
    .#checks.x86_64-linux.check-placement-test \
    .#checks.x86_64-linux.check-dangling-refs \
    .#checks.x86_64-linux.check-dangling-refs-test \
    .#checks.x86_64-linux.check-no-foreign-config \
    .#checks.x86_64-linux.check-no-foreign-config-test \
    .#checks.x86_64-linux.check-dedup \
    .#checks.x86_64-linux.check-dedup-test \
    .#checks.x86_64-linux.check-specialisation-placement \
    .#checks.x86_64-linux.check-specialisation-placement-test \
    .#checks.x86_64-linux.check-helper-naming \
    .#checks.x86_64-linux.check-helper-naming-test \
    .#checks.x86_64-linux.check-no-narration-comments \
    .#checks.x86_64-linux.check-no-narration-comments-test \
    .#checks.x86_64-linux.nixos-exhaustiveness \
    .#checks.x86_64-linux.nixos-exhaustiveness-test \
    .#checks.x86_64-linux.nrb-activate-regex-test \
    .#checks.x86_64-linux.nrb-activate-spec-regex-test \
    .#checks.x86_64-linux.nrb-booted-spec-test \
    .#checks.x86_64-linux.nrb-flag-compat-host-deploy \
    .#checks.x86_64-linux.nrb-flag-spec-base-exclusive \
    .#checks.x86_64-linux.nrb-flag-spec-deploy-exclusive \
    .#checks.x86_64-linux.nrb-flag-spec-check-exclusive \
    .#checks.x86_64-linux.check-no-with-lib \
    .#checks.x86_64-linux.check-no-with-lib-test \
    .#checks.x86_64-linux.check-no-dated-comments \
    .#checks.x86_64-linux.check-no-dated-comments-test \
    .#checks.x86_64-linux.check-mkforce-comment \
    .#checks.x86_64-linux.check-mkforce-comment-test \
    .#checks.x86_64-linux.check-assertion-format \
    .#checks.x86_64-linux.check-assertion-format-test \
    .#checks.x86_64-linux.check-module-docstring \
    .#checks.x86_64-linux.check-module-docstring-test \
    .#checks.x86_64-linux.check-module-class \
    .#checks.x86_64-linux.check-module-class-test \
    .#checks.x86_64-linux.check-secrets-leak \
    .#checks.x86_64-linux.check-secrets-leak-test \
    .#checks.x86_64-linux.check-no-cross-tree-import \
    .#checks.x86_64-linux.check-no-cross-tree-import-test \
    .#checks.x86_64-linux.eval-mylib-mkSimplePackage \
    .#checks.x86_64-linux.eval-mylib-mergeSettings \
    .#checks.x86_64-linux.eval-mylib-mkSettingsOption \
    .#checks.x86_64-linux.eval-mylib-themeCtx \
    .#checks.x86_64-linux.eval-mylib-withStdenvCC \
    .#checks.x86_64-linux.eval-mylib-kernelModuleGuards \
    .#checks.x86_64-linux.eval-mylib-specialisations \
    .#checks.x86_64-linux.consumer-nixos-import \
    .#checks.x86_64-linux.consumer-hm-module-count \
    .#checks.x86_64-linux.eval-no-deprecations-test
  ;;
*)
  echo "unknown mode: $mode" >&2
  exit 2
  ;;
esac
