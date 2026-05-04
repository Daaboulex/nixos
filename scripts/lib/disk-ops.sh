# shellcheck shell=bash
# disk-ops.sh — shared primitives for disk-migration scripts.
# Sourced by: migrate-mbp-sdb.sh, repurpose-kingston.sh.
#
# Caller must set before sourcing:
#   LOG       — absolute path to log file (appended to)
#   AUTO_YES  — "1" to skip interactive confirmations, else empty

# Timestamped log line. Writes to stdout AND appends to $LOG.
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# Log error + exit 1. Does NOT call trap cleanup (caller owns cleanup).
die() {
  echo "ERROR: $*" >&2 | tee -a "$LOG"
  exit 1
}

# Interactive y/N confirmation. Honors $AUTO_YES. Aborts via die() on N.
confirm() {
  local prompt="$1"
  [ "${AUTO_YES:-}" = "1" ] && return 0
  read -r -p "$prompt [y/N] " ans
  [[ $ans =~ ^[Yy] ]] || die "aborted by user"
}

# Phase banner. Updates exported $CURRENT_PHASE (caller's ERR trap reads it).
# shellcheck disable=SC2034  # CURRENT_PHASE consumed by caller's trap handler
phase() {
  CURRENT_PHASE="$1"
  log ""
  log "── Phase $1 ──────────────────────────────────────────────────────"
}
