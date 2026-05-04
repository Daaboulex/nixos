#!/usr/bin/env bash
# shellcheck disable=SC2029 # SSH commands intentionally expand variables client-side
# ============================================================================
# NixOS Remote Deploy Script
# ============================================================================
# Build a NixOS configuration locally and deploy it to a remote host over SSH.
# Optionally sync the nix config repo to the remote host's ~/Documents/nix.
#
# Usage: bash scripts/deploy.sh [options] [hostname]
#
# Options:
#   --sync          Sync nix config repo to remote ~/Documents/nix (rsync)
#   --sync-only     Only sync repo, skip build+deploy
#   --boot          Activate on next reboot instead of immediately
#   --dry           Build only, don't copy or activate
#   --trace         Build with --show-trace
#   --no-portmaster Skip Portmaster stop/start on remote
#   -h, --help      Show this help
#
# If no hostname is given, lists available hosts and prompts interactively.
# ============================================================================
set -euo pipefail

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}>>>${NC} $*"; }
ok() { echo -e "${GREEN}>>>${NC} $*"; }
warn() { echo -e "${YELLOW}>>>${NC} $*"; }
err() { echo -e "${RED}>>>${NC} $*" >&2; }
step() { echo -e "\n${BOLD}${CYAN}── $* ──${NC}\n"; }

# ── Resolve flake root ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAKE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$FLAKE_ROOT/flake.nix" ]; then
  err "No flake.nix found at $FLAKE_ROOT"
  exit 1
fi

# ── Parse arguments ──
HOSTNAME=""
DO_SYNC=false
SYNC_ONLY=false
BOOT_MODE=false
DRY_RUN=false
SHOW_TRACE=false
HANDLE_PORTMASTER=true

while [[ $# -gt 0 ]]; do
  case "$1" in
  --sync)
    DO_SYNC=true
    shift
    ;;
  --sync-only)
    SYNC_ONLY=true
    DO_SYNC=true
    shift
    ;;
  --boot)
    BOOT_MODE=true
    shift
    ;;
  --dry)
    DRY_RUN=true
    shift
    ;;
  --trace)
    SHOW_TRACE=true
    shift
    ;;
  --no-portmaster)
    HANDLE_PORTMASTER=false
    shift
    ;;
  -h | --help)
    echo "Usage: bash $0 [options] [hostname]"
    echo ""
    echo "Build locally on this machine, deploy to a remote NixOS host over SSH."
    echo ""
    echo "Options:"
    echo "  --sync          Sync nix config repo to remote ~/Documents/nix"
    echo "  --sync-only     Only sync repo, skip build+deploy"
    echo "  --boot          Activate on next reboot (not immediately)"
    echo "  --dry           Build only, don't copy or activate"
    echo "  --trace         Build with --show-trace"
    echo "  --no-portmaster Skip Portmaster stop/start on remote"
    echo "  -h, --help      Show this help"
    echo ""
    echo "If no hostname is given, lists available hosts and prompts."
    exit 0
    ;;
  -*)
    err "Unknown option: $1 (try --help)"
    exit 1
    ;;
  *)
    HOSTNAME="$1"
    shift
    ;;
  esac
done

# ── Discover available hosts ──
HOSTS_DIR="$FLAKE_ROOT/parts/hosts"
AVAILABLE_HOSTS=()
LOCAL_HOSTNAME="$(hostname)"

for dir in "$HOSTS_DIR"/*/; do
  h="$(basename "$dir")"
  # Skip the local host — you don't deploy to yourself
  if [ "$h" != "$LOCAL_HOSTNAME" ]; then
    AVAILABLE_HOSTS+=("$h")
  fi
done

if [ ${#AVAILABLE_HOSTS[@]} -eq 0 ]; then
  err "No remote hosts found in $HOSTS_DIR (local host: $LOCAL_HOSTNAME)"
  exit 1
fi

# ── Interactive host selection if not specified ──
if [ -z "$HOSTNAME" ]; then
  echo ""
  echo -e "${BOLD}Available remote hosts:${NC}"
  echo ""
  for i in "${!AVAILABLE_HOSTS[@]}"; do
    echo "  $((i + 1))) ${AVAILABLE_HOSTS[$i]}"
  done
  echo ""
  read -rp "Select host (1-${#AVAILABLE_HOSTS[@]}): " choice
  if [[ ! $choice =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#AVAILABLE_HOSTS[@]} ]; then
    err "Invalid selection"
    exit 1
  fi
  HOSTNAME="${AVAILABLE_HOSTS[$((choice - 1))]}"
fi

# Validate host exists
if [ ! -d "$HOSTS_DIR/$HOSTNAME" ]; then
  err "Host '$HOSTNAME' not found in $HOSTS_DIR"
  exit 1
fi

# ── Discover SSH target ──
# Check for SSH config alias first, fall back to mDNS, then prompt
SSH_TARGET=""
resolve_ssh_target() {
  # Try SSH config alias (matches matchBlocks in HM ssh config)
  local aliases=("$HOSTNAME" "${HOSTNAME}.local")
  for alias in "${aliases[@]}"; do
    if ssh -G "$alias" 2>/dev/null | grep -q "^hostname"; then
      # Test connectivity with 5s timeout
      if ssh -o ConnectTimeout=5 -o BatchMode=yes "$alias" true 2>/dev/null; then
        SSH_TARGET="$alias"
        return 0
      fi
    fi
  done

  # Try mDNS
  local mdns_name="${HOSTNAME}.local"
  if avahi-resolve-host-name "$mdns_name" &>/dev/null; then
    local ip
    ip=$(avahi-resolve-host-name "$mdns_name" 2>/dev/null | awk '{print $2}')
    if [ -n "$ip" ] && ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$ip" true 2>/dev/null; then
      SSH_TARGET="root@$ip"
      return 0
    fi
  fi

  # Prompt for IP
  warn "Could not auto-detect SSH target for '$HOSTNAME'"
  echo ""
  read -rp "Enter IP address or SSH target (e.g. 192.168.2.103): " manual_target
  if [ -z "$manual_target" ]; then
    err "No target provided"
    return 1
  fi
  # Add root@ if no user specified
  if [[ $manual_target != *@* ]]; then
    manual_target="root@$manual_target"
  fi
  SSH_TARGET="$manual_target"
}

step "Connecting to $HOSTNAME"

resolve_ssh_target || exit 1
ok "SSH target: $SSH_TARGET"

# ── Verify SSH connectivity ──
info "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_TARGET" "echo ok" &>/dev/null; then
  err "Cannot SSH to $SSH_TARGET"
  echo ""
  echo "  Possible fixes:"
  echo "  1. Is the host powered on and on the network?"
  echo "  2. Is Portmaster blocking SSH? Run on remote: sudo systemctl stop portmaster"
  echo "  3. Is your SSH key authorized? Add your pubkey to remote ~/.ssh/authorized_keys"
  echo ""
  read -rp "Enter a different SSH target (or Ctrl+C to abort): " alt_target
  if [ -n "$alt_target" ]; then
    [[ $alt_target != *@* ]] && alt_target="root@$alt_target"
    SSH_TARGET="$alt_target"
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_TARGET" "echo ok" &>/dev/null; then
      err "Still cannot connect to $SSH_TARGET. Aborting."
      exit 1
    fi
  else
    exit 1
  fi
fi
ok "SSH connection verified"

# ── Handle Portmaster on remote ──
PORTMASTER_WAS_RUNNING=false
if $HANDLE_PORTMASTER; then
  if ssh "$SSH_TARGET" "systemctl is-active portmaster &>/dev/null" 2>/dev/null; then
    PORTMASTER_WAS_RUNNING=true
    info "Stopping Portmaster on remote (will restart after deploy)..."
    ssh "$SSH_TARGET" "systemctl stop portmaster" 2>/dev/null || true
  fi
fi

# ── Restore Portmaster on exit ──
cleanup() {
  if $PORTMASTER_WAS_RUNNING && $HANDLE_PORTMASTER; then
    info "Restarting Portmaster on remote..."
    ssh -o ConnectTimeout=5 "$SSH_TARGET" "systemctl start portmaster" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ── Sync repo to remote ──
if $DO_SYNC; then
  step "Syncing nix config to $HOSTNAME"

  # Determine remote user home (deploy as root, but sync to user's home)
  REMOTE_USER_HOME=$(ssh "$SSH_TARGET" "getent passwd 1000 | cut -d: -f6" 2>/dev/null)
  if [ -z "$REMOTE_USER_HOME" ]; then
    REMOTE_USER_HOME="/home/user"
    warn "Could not detect remote user home, using $REMOTE_USER_HOME"
  fi
  REMOTE_NIX_DIR="$REMOTE_USER_HOME/Documents/nix"

  info "Syncing $FLAKE_ROOT → $SSH_TARGET:$REMOTE_NIX_DIR"
  ssh "$SSH_TARGET" "mkdir -p '$REMOTE_NIX_DIR'"

  rsync -avz --delete \
    --exclude '.git' \
    --exclude 'repos/' \
    --exclude 'result' \
    --exclude '.direnv' \
    --exclude '.ai-context/.git' \
    "$FLAKE_ROOT/" "$SSH_TARGET:$REMOTE_NIX_DIR/"

  # Fix ownership (rsync as root creates root-owned files)
  REMOTE_USER=$(ssh "$SSH_TARGET" "getent passwd 1000 | cut -d: -f1" 2>/dev/null || echo "user")
  if [[ ! $REMOTE_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    err "Unsafe REMOTE_USER from remote host: '$REMOTE_USER'"
    exit 1
  fi
  ssh "$SSH_TARGET" "chown -R $REMOTE_USER:users '$REMOTE_NIX_DIR'" 2>/dev/null || true

  ok "Repo synced to $REMOTE_NIX_DIR"

  if $SYNC_ONLY; then
    ok "Sync complete (--sync-only mode)"
    exit 0
  fi
fi

# ── Build ──
if ! $SYNC_ONLY; then
  step "Building $HOSTNAME configuration"

  BUILD_ARGS=("$FLAKE_ROOT#nixosConfigurations.$HOSTNAME.config.system.build.toplevel")
  BUILD_ARGS+=("--print-build-logs")
  if $SHOW_TRACE; then
    BUILD_ARGS+=("--show-trace")
  fi

  info "nix build ${BUILD_ARGS[*]}"
  nix build "${BUILD_ARGS[@]}"

  RESULT_PATH=$(readlink "$FLAKE_ROOT/result")
  ok "Build complete: $RESULT_PATH"

  if $DRY_RUN; then
    ok "Dry run — skipping copy and activation"
    echo ""
    echo "  Built store path: $RESULT_PATH"
    echo "  To deploy manually:"
    echo "    nix copy --to ssh://$SSH_TARGET $FLAKE_ROOT/result"
    echo "    ssh $SSH_TARGET nix-env -p /nix/var/nix/profiles/system --set $RESULT_PATH"
    echo "    ssh $SSH_TARGET $RESULT_PATH/bin/switch-to-configuration switch"
    exit 0
  fi

  # ── Copy closure ──
  step "Copying closure to $HOSTNAME"

  info "This may take a while on first deploy..."
  nix copy --to "ssh://$SSH_TARGET" "$FLAKE_ROOT/result"

  ok "Closure copied"

  # ── Activate ──
  SWITCH_ACTION="switch"
  if $BOOT_MODE; then
    SWITCH_ACTION="boot"
    step "Setting $HOSTNAME to activate on next reboot"
  else
    step "Activating configuration on $HOSTNAME"
  fi

  ssh "$SSH_TARGET" "nix-env -p /nix/var/nix/profiles/system --set $RESULT_PATH"
  ssh "$SSH_TARGET" "$RESULT_PATH/bin/switch-to-configuration $SWITCH_ACTION"

  ok "Configuration activated ($SWITCH_ACTION)"

  # ── Verify ──
  step "Verifying deployment"

  REMOTE_VERSION=$(ssh -o ConnectTimeout=10 "$SSH_TARGET" "nixos-version" 2>/dev/null || echo "unknown")
  ok "$HOSTNAME running: $REMOTE_VERSION"
fi

echo ""
echo -e "${GREEN}${BOLD}Deploy complete!${NC}"
echo ""
