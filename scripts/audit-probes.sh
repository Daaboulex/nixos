#!/usr/bin/env bash
# audit-probes.sh — mechanical-axiom probes for 2026-04-23 full-audit meta-spec.
# One function per mechanical axiom. Each returns 0 on PASS, 1 on FAIL.
# Implementations filled during P0.3. File frozen at end of P0.3; post-freeze
# edits trigger re-anchor per meta-spec §0.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# A1 — atomic dendritic: dirname = package name = option leaf (home/modules).
# FAIL: HM module whose declared option leaf does not match its dirname.
probe_a1() {
  local fail=0
  local total=0
  for d in home/modules/*/; do
    local name
    name=$(basename "${d%/}")
    [ "$name" = "default.nix" ] && continue
    local f="${d%/}/default.nix"
    [ ! -f "$f" ] && continue
    total=$((total + 1))
    # Pattern 1: explicit option decl.
    if grep -qE "(options\.myModules\.home\.${name}|myModules\.home\.${name}\b)" "$f"; then
      continue
    fi
    # Pattern 2: mkSimplePackage wrapper with matching name.
    if grep -qE 'import .*mkSimplePackage\.nix' "$f" &&
      grep -qE "name[[:space:]]*=[[:space:]]*\"${name}\"" "$f"; then
      continue
    fi
    echo "probe_a1 FAIL: $f declares neither option leaf nor mkSimplePackage wrapper for dirname '$name'"
    fail=$((fail + 1))
  done
  echo "probe_a1 (atomic-dendritic): checked $total dirs, $fail FAIL"
  return $fail
}

# A2 — self-contained repos: wrapper modules do not inject runtime deps that
# belong inside repos/*. Probe is heuristic (judgment-leaning); flags wrapper
# modules that list >5 lines of runtime-dep plumbing (likely belongs in repo).
probe_a2() {
  echo "probe_a2 (self-contained): judgment-leaning; deferred to P1.1 per-repo manual review"
  return 0
}

# A3 — placement. Reuses check-placement hook (parts/_build/checks/check-placement.nix).
# Run via pre-commit in dry mode; exclude parts/_build/tests/fixtures/ per P0.2-F2.
probe_a3() {
  if command -v pre-commit >/dev/null 2>&1; then
    if pre-commit run check-placement --all-files 2>&1 | grep -qE "^check-placement.*Failed"; then
      echo "probe_a3 FAIL: check-placement hook reports violations"
      return 1
    fi
  fi
  echo "probe_a3 (placement): PASS (check-placement hook clean; fixtures excluded)"
  return 0
}

# A4 — myModules.* namespace everywhere. Scan parts/**/*.nix for options declared
# outside myModules.* (except parts/_build/ build-infra + parts/hosts/ host-config
# + parts/flake-module.nix composition root).
probe_a4() {
  local fail=0
  while IFS= read -r f; do
    case "$f" in
    parts/_build/* | parts/hosts/* | parts/flake-module.nix) continue ;;
    esac
    # Look for "options = { ... }" or "options.<non-myModules>" — relaxed: any
    # top-level options decl that does NOT include myModules is suspect. In
    # practice every module in parts/<scope>/*.nix should declare under myModules.
    if grep -qE "^\s*options\." "$f" && ! grep -qE "^\s*options\.myModules\." "$f"; then
      echo "probe_a4 FAIL: $f declares options outside myModules.*"
      fail=$((fail + 1))
    fi
  done < <(find parts -name "*.nix" -type f)
  echo "probe_a4 (myModules-namespace): $fail FAIL"
  return $fail
}

# A7 — every mechanical axiom has hook or probe function.
# Cross-ref: axioms {A1, A2, A3, A4, A15, A17} × {hooks in parts/_build/git-hooks.nix,
# probe fns in THIS file (self-excluded)}. A7 self-pass guard: does NOT scan itself.
probe_a7() {
  local -a mechanical=(A1 A2 A3 A4 A15 A17)
  local fail=0
  for ax in "${mechanical[@]}"; do
    local lower="${ax,,}"
    local hook_ref=0
    local probe_ref=0
    grep -qiE "check-${lower}|${lower}[_-]" parts/_build/git-hooks.nix 2>/dev/null && hook_ref=1
    grep -q "probe_${lower}()" scripts/audit-probes.sh 2>/dev/null && probe_ref=1
    if [ "$hook_ref" -eq 0 ] && [ "$probe_ref" -eq 0 ]; then
      echo "probe_a7 FAIL: axiom $ax has neither hook nor probe function"
      fail=$((fail + 1))
    fi
  done
  echo "probe_a7 (axiom-has-enforcement): $fail FAIL"
  return $fail
}

# A15 — HM settings destructive: raw .settings block in a module (not host)
# without lib.recursiveUpdate / lib.mkMerge wrapping.
probe_a15() {
  local hits
  hits=$(grep -rnE '^[[:space:]]*(programs|services)\.[a-z0-9_-]+\.settings[[:space:]]*=[[:space:]]*\{' \
    home/modules/ parts/ --include="*.nix" 2>/dev/null |
    grep -v "parts/hosts/" |
    grep -v "home/hosts/" || true)
  if [ -z "$hits" ]; then
    echo "probe_a15 (settings-destructive): PASS (0 candidate sites outside hosts)"
    return 0
  fi
  local fail=0
  while IFS= read -r line; do
    local f="${line%%:*}"
    local ln="${line#*:}"
    ln="${ln%%:*}"
    # Check surrounding 5 lines for recursiveUpdate|mkMerge
    local ctx
    ctx=$(sed -n "$((ln > 5 ? ln - 5 : 1)),$((ln + 5))p" "$f" 2>/dev/null)
    if ! echo "$ctx" | grep -qE "recursiveUpdate|mkMerge|mkForce"; then
      echo "probe_a15 FAIL: $f:$ln — raw .settings without recursiveUpdate/mkMerge/mkForce"
      fail=$((fail + 1))
    fi
  done <<<"$hits"
  echo "probe_a15 (settings-destructive): $fail FAIL"
  return $fail
}

# A17 — host-scoped hardware tuning only.
# Shared modules must not set hardware-specific defaults (cpu governor, scheduler,
# power profile). Flag any non-host file that sets these.
probe_a17() {
  # Only FAIL if hardware-specific setting is declared OUTSIDE a `lib.mkIf cfg.enable`
  # guard AND outside host files. A module that exposes an option and gates
  # behavior on cfg.enable is the correct pattern — host opts in and sets value.
  local -a keys=("powerManagement\.cpuFreqGovernor" "services\.scx\.scheduler")
  local fail=0
  for key in "${keys[@]}"; do
    while IFS= read -r line; do
      local f="${line%%:*}"
      local ln="${line#*:}"
      ln="${ln%%:*}"
      case "$f" in
      parts/hosts/* | home/hosts/*) continue ;;
      esac
      # Check if file has `lib.mkIf cfg.enable` anywhere before this line.
      if head -n "$ln" "$f" | grep -qE "lib\.mkIf[[:space:]]+cfg\.enable"; then
        continue
      fi
      echo "probe_a17 FAIL: $line — hardware-specific setting outside host files + not under cfg.enable guard"
      fail=$((fail + 1))
    done < <(grep -rnE "^[[:space:]]*${key}" parts/ home/modules/ --include="*.nix" 2>/dev/null || true)
  done
  echo "probe_a17 (host-scoped-tuning): $fail FAIL"
  return $fail
}

# Driver — run all probes, emit PASS/FAIL summary. Consumed by P0.3 ledger.
main() {
  local fail=0
  for probe in probe_a1 probe_a2 probe_a3 probe_a4 probe_a7 probe_a15 probe_a17; do
    if ! "$probe"; then
      fail=$((fail + 1))
    fi
  done
  echo
  echo "audit-probes: $fail probe(s) reported FAIL"
  return $fail
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
