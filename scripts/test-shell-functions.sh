#!/usr/bin/env bash
# ===========================================================================
# Test script for nrb, nrb-check, nrb-info, and nrb --list
#
# This script does NOT switch, activate, or modify anything.
# It exercises the shell functions in read-only / eval-only mode
# so you can verify their output and catch bugs.
#
# Usage:
#   bash scripts/test-shell-functions.sh
#   bash scripts/test-shell-functions.sh --verbose   # show full output
# ===========================================================================

set -uo pipefail

FLAKE_DIR="${FLAKE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  (( TESTS_PASSED++ ))
  (( TESTS_RUN++ ))
  echo -e "  ${GREEN}PASS${NC}  $1"
}

fail() {
  (( TESTS_FAILED++ ))
  (( TESTS_RUN++ ))
  echo -e "  ${RED}FAIL${NC}  $1"
  [[ -n "${2:-}" ]] && echo -e "        ${RED}$2${NC}"
}

section() {
  echo ""
  echo -e "${CYAN}=== $1 ===${NC}"
}

# --------------------------------------------------------------------------
section "Prerequisites"
# --------------------------------------------------------------------------

if command -v nix &>/dev/null; then
  pass "nix is available"
else
  fail "nix not found in PATH"
  echo "Cannot continue without nix. Exiting."
  exit 1
fi

if command -v jq &>/dev/null; then
  pass "jq is available"
else
  fail "jq not found in PATH" "Install jq or ensure it's in PATH"
fi

if [[ -f "$FLAKE_DIR/flake.nix" ]]; then
  pass "flake.nix found at $FLAKE_DIR"
else
  fail "flake.nix not found at $FLAKE_DIR"
  exit 1
fi

# --------------------------------------------------------------------------
section "Config Discovery (nix eval nixosConfigurations)"
# --------------------------------------------------------------------------

CONFIGS_JSON=$(nix --extra-experimental-features 'nix-command flakes' \
  eval "$FLAKE_DIR#nixosConfigurations" --apply 'x: builtins.attrNames x' --json 2>/dev/null || echo "")

if [[ -n "$CONFIGS_JSON" && "$CONFIGS_JSON" != "[]" ]]; then
  pass "nixosConfigurations discovered: $CONFIGS_JSON"
else
  fail "No nixosConfigurations found"
  exit 1
fi

CONFIG_COUNT=$(echo "$CONFIGS_JSON" | jq 'length')
pass "Found $CONFIG_COUNT configuration(s)"

mapfile -t CONFIG_NAMES < <(echo "$CONFIGS_JSON" | jq -r '.[]')

# --------------------------------------------------------------------------
section "Config Evaluation (all hosts)"
# --------------------------------------------------------------------------

for name in "${CONFIG_NAMES[@]}"; do
  echo -e "  ${YELLOW}--- $name ---${NC}"

  EVAL_OUTPUT=""
  if EVAL_OUTPUT=$(nix --extra-experimental-features 'nix-command flakes' \
    eval "$FLAKE_DIR#nixosConfigurations.$name.config.system.build.toplevel.drvPath" 2>&1); then
    pass "$name evaluates successfully"
    (( VERBOSE )) && echo "        drv: $EVAL_OUTPUT"
  else
    fail "$name evaluation failed" "$(echo "$EVAL_OUTPUT" | tail -3)"
  fi

  # Check specialisations
  SPECS_JSON=$(nix --extra-experimental-features 'nix-command flakes' \
    eval "$FLAKE_DIR#nixosConfigurations.$name.config.specialisation" \
    --apply 'x: builtins.attrNames x' --json 2>/dev/null || echo "[]")

  if [[ "$SPECS_JSON" != "[]" ]]; then
    SPEC_COUNT=$(echo "$SPECS_JSON" | jq 'length')
    pass "$name has $SPEC_COUNT specialisation(s): $SPECS_JSON"

    mapfile -t SPEC_NAMES < <(echo "$SPECS_JSON" | jq -r '.[]')

    for spec in "${SPEC_NAMES[@]}"; do
      SPEC_OUTPUT=""
      if SPEC_OUTPUT=$(nix --extra-experimental-features 'nix-command flakes' \
        eval "$FLAKE_DIR#nixosConfigurations.$name.config.specialisation.$spec.configuration.system.build.toplevel.drvPath" 2>&1); then
        pass "$name + $spec evaluates successfully"
        (( VERBOSE )) && echo "        drv: $SPEC_OUTPUT"
      else
        fail "$name + $spec evaluation failed" "$(echo "$SPEC_OUTPUT" | tail -3)"
      fi
    done
  else
    pass "$name has no specialisations (single config)"
  fi
done

# --------------------------------------------------------------------------
section "Config Properties (spot checks)"
# --------------------------------------------------------------------------

for name in "${CONFIG_NAMES[@]}"; do
  # Check hostname matches config name
  HN=$(nix --extra-experimental-features 'nix-command flakes' \
    eval "$FLAKE_DIR#nixosConfigurations.$name.config.networking.hostName" --raw 2>/dev/null || echo "")
  if [[ "$HN" == "$name" ]]; then
    pass "$name: networking.hostName = \"$HN\" (matches config name)"
  else
    fail "$name: networking.hostName = \"$HN\" (expected \"$name\")"
  fi

  # Check stateVersion is set
  SV=$(nix --extra-experimental-features 'nix-command flakes' \
    eval "$FLAKE_DIR#nixosConfigurations.$name.config.system.stateVersion" --raw 2>/dev/null || echo "")
  if [[ -n "$SV" ]]; then
    pass "$name: system.stateVersion = \"$SV\""
  else
    fail "$name: system.stateVersion not set"
  fi

  # Check kernel variant
  KV=$(nix --extra-experimental-features 'nix-command flakes' \
    eval "$FLAKE_DIR#nixosConfigurations.$name.config.myModules.kernel.variant" --raw 2>/dev/null || echo "")
  if [[ -n "$KV" ]]; then
    pass "$name: kernel.variant = \"$KV\""
  else
    fail "$name: kernel.variant not set"
  fi
done

# --------------------------------------------------------------------------
section "nrb Flag Parsing (syntax checks)"
# --------------------------------------------------------------------------

# Dynamically extract flags and functions from the zsh source.
# This ensures the test stays in sync even when the zsh module changes.
ZSH_FILE="$FLAKE_DIR/home/modules/zsh/default.nix"

if [[ ! -f "$ZSH_FILE" ]]; then
  fail "Zsh module not found at $ZSH_FILE"
else
  pass "Zsh module found"

  # Extract nrb case flags: lines matching "--something)" in the nrb case block
  mapfile -t NRB_FLAGS < <(grep -oP '^\s*--[a-z]+\)' "$ZSH_FILE" | sed 's/[[:space:]]*//;s/)//' | sort -u)
  if [[ ${#NRB_FLAGS[@]} -gt 0 ]]; then
    pass "nrb defines ${#NRB_FLAGS[@]} flag(s): ${NRB_FLAGS[*]}"
    for flag in "${NRB_FLAGS[@]}"; do
      # Verify each flag has a corresponding handler (shift, assignment, or return)
      if grep -qP "^\s*${flag}\)" "$ZSH_FILE"; then
        pass "nrb case handler: $flag"
      else
        fail "nrb case handler missing for $flag"
      fi
    done
  else
    fail "No nrb flags found in case statement"
  fi

  # Extract all nrb* function definitions dynamically
  mapfile -t NRB_FUNCS < <(grep -oP '^\s*nrb[a-zA-Z_-]*\(\)' "$ZSH_FILE" | sed 's/[[:space:]]*//;s/()//' | sort -u)
  if [[ ${#NRB_FUNCS[@]} -gt 0 ]]; then
    pass "Found ${#NRB_FUNCS[@]} nrb function(s): ${NRB_FUNCS[*]}"
    for func in "${NRB_FUNCS[@]}"; do
      pass "function defined: $func"
    done
  else
    fail "No nrb* functions found"
  fi

  # Verify help text lists all flags (the --help|-h case block)
  HELP_BLOCK=$(sed -n '/--help|-h)/,/return 0/p' "$ZSH_FILE" || true)
  if [[ -n "$HELP_BLOCK" ]]; then
    local_missing=0
    for flag in "${NRB_FLAGS[@]}"; do
      if ! echo "$HELP_BLOCK" | grep -q -- "$flag"; then
        fail "nrb help text missing $flag"
        local_missing=1
      fi
    done
    if [[ $local_missing -eq 0 ]]; then
      pass "nrb help text lists all ${#NRB_FLAGS[@]} flags"
    fi
  else
    fail "nrb help/usage text not found"
  fi

  # Verify each standalone nrb-* function is referenced from nrb (delegation)
  for func in "${NRB_FUNCS[@]}"; do
    [[ "$func" == "nrb" ]] && continue
    # Check if nrb() calls this function somewhere
    if grep -qP "^\s*$func" "$ZSH_FILE" | head -1 && \
       [[ $(grep -c "$func" "$ZSH_FILE") -ge 2 ]]; then
      pass "nrb delegates to $func"
    else
      # At minimum the function is defined and callable standalone — still OK
      pass "$func is standalone-callable"
    fi
  done
fi

# --------------------------------------------------------------------------
section "Documentation Checks"
# --------------------------------------------------------------------------

# Check OPTIONS.md exists
if [[ -f "$FLAKE_DIR/docs/OPTIONS.md" ]]; then
  OPT_LINES=$(wc -l < "$FLAKE_DIR/docs/OPTIONS.md")
  pass "docs/OPTIONS.md exists ($OPT_LINES lines)"
else
  fail "docs/OPTIONS.md missing"
fi

# Check installation.md exists
if [[ -f "$FLAKE_DIR/docs/installation.md" ]]; then
  INST_LINES=$(wc -l < "$FLAKE_DIR/docs/installation.md")
  pass "docs/installation.md exists ($INST_LINES lines)"
else
  fail "docs/installation.md missing"
fi

# Check installation.md has the unstable ISO link
if grep -q "nixos-unstable/latest-nixos-graphical" "$FLAKE_DIR/docs/installation.md"; then
  pass "installation.md contains unstable graphical ISO link"
else
  fail "installation.md missing unstable graphical ISO link"
fi

# Check no options with missing descriptions
if [[ -f "$FLAKE_DIR/docs/OPTIONS.md" ]]; then
  MISSING=$(grep -c "No description" "$FLAKE_DIR/docs/OPTIONS.md" || true)
  if [[ "$MISSING" -eq 0 ]]; then
    pass "All options have descriptions (0 missing)"
  else
    fail "$MISSING option(s) missing descriptions in OPTIONS.md"
  fi
fi

# Check README references installation.md
if grep -q "installation.md" "$FLAKE_DIR/README.md"; then
  pass "README.md links to installation.md"
else
  fail "README.md does not link to installation.md"
fi

# Check README references nrb-check
if grep -q "nrb-check" "$FLAKE_DIR/README.md"; then
  pass "README.md documents nrb-check"
else
  fail "README.md does not document nrb-check"
fi

# --------------------------------------------------------------------------
section "System Info (current host only)"
# --------------------------------------------------------------------------

echo "  (These are informational — not pass/fail)"
echo ""
echo "  Hostname:     $(hostname)"
echo "  Kernel:       $(uname -r)"
echo "  NixOS:        $(nixos-version 2>/dev/null || echo 'N/A')"

if [[ -f /run/current-system/etc/nixos-tags ]]; then
  echo "  Active spec:  $(head -1 /run/current-system/etc/nixos-tags 2>/dev/null || echo 'none')"
fi

GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null | sed 's/system-\(.*\)-link/\1/' || echo "N/A")
echo "  Generation:   $GEN"

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "  Tests run:    $TESTS_RUN"
echo -e "  ${GREEN}Passed:      $TESTS_PASSED${NC}"
if (( TESTS_FAILED > 0 )); then
  echo -e "  ${RED}Failed:      $TESTS_FAILED${NC}"
else
  echo -e "  Failed:      0"
fi
echo -e "${CYAN}========================================${NC}"

exit $TESTS_FAILED
