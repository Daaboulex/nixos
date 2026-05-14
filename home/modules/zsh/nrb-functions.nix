# nrb-functions — NixOS rebuild helper functions (nrb, nrb-check, nrb-info).
# Extracted for testability. Consumed by home/modules/zsh/default.nix and parts/_build/tests/nrb.nix.
{ pkgs, flakeDir }:
{
  nrb = ''
    nrb() {
      # Function-local option scope — restored on return.
      # null_glob: unmatched globs expand to empty (not an error).
      # no_nomatch: literal pass-through if glob has no matches (defensive
      # for cases where null_glob interaction with command substitution differs).
      setopt local_options null_glob no_nomatch pipefail no_monitor
      local trace_flag="" dry=0 boot=0 update=0 update_no_kernel=0 check=0 target="" deploy_target=""
      local flake_dir="''${FLAKE_DIR:-${flakeDir}}"

      # Terminal rendering — respect NO_COLOR, detect capabilities
      local _c_reset="" _c_bold="" _c_dim="" _c_red="" _c_green="" _c_yellow="" _c_blue="" _c_cyan=""
      local _i_ok="OK" _i_fail="FAIL" _i_warn="!!" _i_info=">>" _i_arrow="->"
      if [[ -z "''${NO_COLOR:-}" && -t 1 && "''${TERM:-}" != "dumb" ]]; then
        _c_reset=$'\033[0m' _c_bold=$'\033[1m' _c_dim=$'\033[2m'
        _c_red=$'\033[31m' _c_green=$'\033[32m' _c_yellow=$'\033[33m'
        _c_blue=$'\033[34m' _c_cyan=$'\033[36m'
        if [[ "$(locale charmap 2>/dev/null)" == "UTF-8" ]]; then
          _i_ok="✔" _i_fail="✘" _i_warn="⚠" _i_info="▶" _i_arrow="→"
        fi
      fi
      _msg_ok()   { echo -e "''${_c_green}''${_i_ok}''${_c_reset} $*"; }
      _msg_fail() { echo -e "''${_c_red}''${_i_fail}''${_c_reset} $*" >&2; }
      _msg_warn() { echo -e "''${_c_yellow}''${_i_warn}''${_c_reset} $*" >&2; }
      _msg_info() { echo -e "''${_c_blue}''${_i_info}''${_c_reset} $*"; }
      _msg_step() { echo -e "''${_c_bold}''${_i_arrow}''${_c_reset} $*"; }
      _msg_dim()  { echo -e "''${_c_dim}$*''${_c_reset}"; }
      # Run a command with an inline spinner showing elapsed time.
      # Usage: _with_spinner "label" command arg1 arg2 ...
      # stdout/stderr of the command are inherited (not swallowed).
      _with_spinner() {
        local _lbl="$1"; shift
        "$@" &
        local _pid=$! _elapsed=0
        local -a _frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        [[ -z "$_c_reset" ]] && _frames=('-' '\' '|' '/')
        trap "kill $_pid 2>/dev/null; printf '\r\033[K'; trap - INT TERM; return 130" INT TERM
        while kill -0 "$_pid" 2>/dev/null; do
          printf "\r  ''${_c_dim}%s %s (%ds)''${_c_reset}  " "''${_frames[$(( _elapsed % ''${#_frames[@]} + 1 ))]}" "$_lbl" "$_elapsed"
          sleep 1
          (( _elapsed++ ))
        done
        trap - INT TERM
        printf "\r\033[K"
        wait "$_pid"
      }

      # Parse flags
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --trace)  trace_flag="--show-trace"; shift ;;
          --dry)    dry=1; shift ;;
          --boot)   boot=1; shift ;;
          --update) update=1; shift ;;
          --update-no-kernel) update_no_kernel=1; shift ;;
          --check)  check=1; shift ;;
          --host)
            if [[ -z "''${2:-}" || "$2" == --* ]]; then
              echo "ERROR: --host requires a hostname argument"
              return 1
            fi
            target="$2"; shift 2
            ;;
          --deploy)
            if [[ -z "''${2:-}" || "$2" == --* ]]; then
              echo "ERROR: --deploy requires a hostname argument"
              return 1
            fi
            deploy_target="$2"; shift 2
            ;;
          --help|-h)
            echo "nrb — NixOS Rebuild Helper"
            echo ""
            echo "Usage: nrb [FLAGS]"
            echo ""
            echo "Flags:"
            echo "  --update             Update all flake inputs before building"
            echo "  --update-no-kernel   Update inputs that won't trigger a kernel rebuild"
            echo "                       (auto-detects kernel deps — no hardcoded skip list)"
            echo "  --dry                Build + show diff, don't activate"
            echo "  --boot               Build + activate on next reboot (not immediately)"
            echo "  --trace              Show full Nix stack trace on errors"
            echo "  --check              Evaluate all configs without building (fast sanity)"
            echo "  --host X             Build a specific nixosConfiguration (default: \$HOST)"
            echo "  --deploy X           Build X's config locally, push + activate on X via SSH"
            echo "                       Requires: key-based SSH + NOPASSWD sudo on target"
            echo "  --list               Show all available configurations and deploy targets"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Flags can be combined: nrb --update --dry --trace"
            echo ""
            echo "Related commands:"
            echo "  nrb-check    Standalone config evaluator (same as nrb --check)"
            echo "  nrb-info     Show current system state, generations, and configs"
            return 0
            ;;
          --list)
            local _jq="${pkgs.jq}/bin/jq"
            local name marker specs spec
            echo "NixOS Configurations:"
            echo ""
            nix --extra-experimental-features 'nix-command flakes' \
              eval "$flake_dir#nixosConfigurations" --apply 'x: builtins.attrNames x' --json 2>/dev/null \
              | $_jq -r '.[]' | while read -r name; do
                if [[ "$name" == "$(hostname)" ]]; then
                  marker="  (current — nrb)"
                else
                  marker="  (deploy target — nrb --deploy $name)"
                fi
                echo "  $name$marker"

                # Show specialisations for each config
                specs=$(nix --extra-experimental-features 'nix-command flakes' \
                  eval "$flake_dir#nixosConfigurations.$name.config.specialisation" \
                  --apply 'x: builtins.attrNames x' --json 2>/dev/null || echo "[]")
                if [[ "$specs" != "[]" ]]; then
                  echo "$specs" | $_jq -r '.[]' | while read -r spec; do
                    echo "    + $spec  (boot variant)"
                  done
                fi
              done
            return 0
            ;;
          *)
            echo "Unknown flag: $1 (try nrb --help)"
            return 1
            ;;
        esac
      done

      local hostname="''${target:-$(hostname)}"

      # ADV-001: --host and --deploy are mutually exclusive
      if [[ -n "$target" && -n "$deploy_target" ]]; then
        _msg_fail "--host and --deploy cannot be combined"
        _msg_dim "  --host builds for THIS machine. --deploy builds and pushes to ANOTHER machine."
        return 1
      fi

      # ADV-002: --deploy incompatible with --boot, --update, --update-no-kernel
      if [[ -n "$deploy_target" ]]; then
        if (( boot )); then
          _msg_fail "--deploy does not support --boot"
          return 1
        fi
        if (( update )); then
          _msg_fail "--deploy does not support --update (run nrb --update separately first)"
          return 1
        fi
        if (( update_no_kernel )); then
          _msg_fail "--deploy does not support --update-no-kernel (run it separately first)"
          return 1
        fi
      fi

      # ── Remote deploy mode ──
      # Build target config locally, copy closure to target, activate via SSH.
      # Profile-linked + bootloader-updated on the remote. Proper NixOS workflow.
      # Requires: passwordless SSH + NOPASSWD sudo on target for nix-env + switch.
      if [[ -n "$deploy_target" ]]; then
        if (( dry )); then
          _msg_fail "--deploy does not support --dry (remote activation is all-or-nothing)"
          return 1
        fi
        if (( check )); then
          _msg_fail "--deploy does not support --check (use nrb --check separately)"
          return 1
        fi
        local _dt="$deploy_target"
        local _dt_ssh=""
        local _build_dir
        _build_dir=$(mktemp -d) || {
          _msg_fail "Cannot create temp dir for deploy"
          return 1
        }
        _deploy_cleanup() { rm -rf "$_build_dir" 2>/dev/null; trap - INT TERM HUP; }
        trap '_deploy_cleanup' INT TERM HUP
        _msg_step "Deploy mode: building $_dt config locally, deploying via SSH"

        # Resolve target — try bare hostname, then .local (mDNS), then IP from ssh_config
        local _try
        for _try in "$_dt" "''${_dt}.local"; do
          if ssh -o ConnectTimeout=5 -o BatchMode=yes "$_try" true 2>/dev/null; then
            _dt_ssh="$_try"
            break
          fi
        done
        if [[ -z "$_dt_ssh" ]]; then
          _msg_fail "Cannot reach $_dt via SSH"
          _msg_dim "  Tried: $_dt, ''${_dt}.local"
          _msg_dim "  Ensure target is on the network and SSH key auth is configured."
          _deploy_cleanup; return 1
        fi
        [[ "$_dt_ssh" != "$_dt" ]] && _msg_dim "  resolved via $_dt_ssh"

        # Verify sudo works without password on target
        if ! ssh -o ConnectTimeout=5 "$_dt_ssh" 'sudo -n /run/current-system/sw/bin/true' 2>/dev/null; then
          _msg_fail "$_dt requires NOPASSWD sudo for deploy"
          _msg_dim "  Target must have myModules.security.hardening.enable = true (provides nrb-activate)"
          _deploy_cleanup; return 1
        fi

        # Build (uses $_dt for the nix config name, $_dt_ssh for SSH)
        _msg_step "Building $flake_dir#nixosConfigurations.$_dt ..."
        if ! nix build "''${flake_dir}#nixosConfigurations.''${_dt}.config.system.build.toplevel" \
          -o "$_build_dir/result" $trace_flag; then
          _msg_fail "Build failed for $_dt"
          _deploy_cleanup; return 1
        fi
        local _store_path
        _store_path=$(readlink -f "$_build_dir/result")
        _msg_ok "Built: $_store_path"

        # Copy closure to target
        _msg_step "Copying closure to $_dt_ssh ..."
        if ! _with_spinner "copying closure to $_dt_ssh" \
          env NIX_SSHOPTS="-o ConnectTimeout=30" nix copy --to "ssh://''${_dt_ssh}" "$_store_path"; then
          _msg_fail "Failed to copy closure to $_dt_ssh"
          _deploy_cleanup; return 1
        fi
        _msg_ok "Closure copied"
        trap '_deploy_cleanup' INT TERM HUP

        # Activate on target — split into two steps for safe rollback.
        # Step 1: link profile. Step 2: activate. If step 2 fails,
        # rollback the profile so next boot doesn't use the broken config.
        _msg_step "Linking profile on $_dt ..."
        if ! ssh -t "$_dt_ssh" "sudo nrb-activate set-profile '$_store_path'"; then
          _msg_fail "Profile link failed on $_dt — no changes made"
          _deploy_cleanup; return 1
        fi

        _msg_step "Activating on $_dt ..."
        if ! ssh -t "$_dt_ssh" "sudo nrb-activate switch '$_store_path'"; then
          _msg_fail "Activation failed on $_dt — profile was linked but services not switched"
          _msg_warn "  Remote is in a half-switched state. To fix on $_dt, run:"
          _msg_dim "    sudo nix-env -p /nix/var/nix/profiles/system --rollback"
          _msg_dim "    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
          _deploy_cleanup; return 1
        fi

        _deploy_cleanup
        _msg_ok "Deployed to $_dt"
        return 0
      fi

      # Pre-flight: hostname safety — prevent applying wrong config to wrong machine.
      # nixos-rebuild switch with a foreign hostname destroys the running system
      # (removes users, services, firewall rules for the real host).
      local actual_host
      actual_host=$(hostname)
      if [[ "$hostname" != "$actual_host" ]]; then
        _msg_fail "Refusing to switch: target '$hostname' ≠ this machine '$actual_host'"
        _msg_dim "  To deploy to another machine: nrb --deploy $hostname"
        return 1
      fi

      # Pre-flight: flake directory must exist
      if [[ ! -d "$flake_dir" ]]; then
        _msg_fail "Flake directory not found: $flake_dir"
        _msg_dim "  Set FLAKE_DIR or configure myModules.home.zsh.flakeDir"
        return 1
      fi
      if [[ ! -f "$flake_dir/flake.nix" ]]; then
        _msg_fail "No flake.nix in $flake_dir"
        return 1
      fi

      # Pre-flight: nix daemon must be running
      if ! nix store info --store daemon 2>/dev/null; then
        _msg_fail "Nix daemon not responding"
        _msg_dim "  Check: sudo systemctl status nix-daemon"
        return 1
      fi

      # Pre-flight: disk space on /nix/store partition
      local _store_avail_mb
      _store_avail_mb=$(df -BM --output=avail /nix/store 2>/dev/null | tail -1 | tr -d ' M')
      if [[ -n "$_store_avail_mb" ]]; then
        if (( _store_avail_mb < 500 )); then
          _msg_fail "Only ''${_store_avail_mb}MB free on /nix/store — need at least 500MB"
          _msg_dim "  Run: sudo nix-collect-garbage -d && sudo nix-store --optimize"
          return 1
        elif (( _store_avail_mb < 2048 )); then
          _msg_warn "Low disk: ''${_store_avail_mb}MB free on /nix/store"
          _msg_dim "  Consider: sudo nix-collect-garbage -d"
        fi
      fi

      # /tmp space check — sandbox builds use /tmp
      local _tmp_avail_mb
      _tmp_avail_mb=$(df -BM --output=avail /tmp 2>/dev/null | tail -1 | tr -d ' M')
      if [[ -n "$_tmp_avail_mb" ]] && (( _tmp_avail_mb < 1024 )); then
        _msg_warn "Low /tmp space: ''${_tmp_avail_mb}MB free (kernel builds need ~2GB)"
      fi

      # --check: evaluate all configs without building
      if (( check )); then
        nrb-check $trace_flag
        return $?
      fi

      # Update flake inputs — mutually exclusive flags
      if (( update && update_no_kernel )); then
        _msg_fail "--update and --update-no-kernel are mutually exclusive"
        return 1
      fi

      if (( update )); then
        _msg_step "Updating flake inputs (all, including kernel)..."
        if ! nix flake update --flake "$flake_dir"; then
          _msg_fail "Flake update failed!"
          return 1
        fi
        echo ""
      elif (( update_no_kernel )); then
        # Autonomous kernel-safe update. Works against whatever kernels
        # the host actually resolves to at eval time — no hardcoded input
        # names, no skip lists, no user maintenance. Crucially, this
        # includes EVERY specialisation's kernel: MBP has a default
        # `xanmod` generation plus a `cachyos-lto-v2` specialisation,
        # and each uses a different kernel derivation. Rebuilding either
        # is a 45-90 min penalty, so both are protected.
        #
        # Algorithm:
        #   1. Build JSON map { default: drv, <spec-name>: drv, ... } of
        #      every kernel this host can boot.
        #   2. Full speculative `nix flake update`.
        #   3. Rebuild the map. If identical → keep update.
        #   4. If any entry differs → for each root input whose rev moved,
        #      restore the lock, update ONLY that input, rebuild the map,
        #      compare. Matches baseline map → safe. Differs → skip.
        #   5. Restore baseline lock, batch-apply only safe inputs.
        #
        # Cost: 1 baseline eval + 1 post-update eval + N per-input evals
        # where N = inputs whose rev actually moved. Typical daily update
        # = 1-5 moved inputs → ~1-3 min on MBP.

        local _lock_backup _mk_kern_expr _lock_guard _eval_log _escaped_dir _escaped_host
        local _lock_fd=""
        _lock_backup=$(mktemp -t nrb-flake-lock-XXXXXX) || {
          _msg_fail "mktemp failed"
          return 1
        }
        # Persistent log for nix-eval stderr. Survives function exit
        # so failing runs can be diagnosed. Append (not truncate) with
        # date header — previous run diagnostics preserved.
        _eval_log="''${XDG_CACHE_HOME:-$HOME/.cache}/nrb-update-kernel-safe.log"
        mkdir -p "''${_eval_log:h}" 2>/dev/null
        echo "--- $(date -Iseconds) ---" >> "$_eval_log"

        # Concurrency guard using flock on a dedicated fd. The fd is
        # opened in a subshell-safe way and ALWAYS closed on exit via
        # the _nrb_cleanup function — preventing the stale-lock bug
        # where exec 9> leaked fd 9 to the parent shell indefinitely.
        _lock_guard="$flake_dir/.nrb-update.lock"
        _lock_fd=""
        if command -v ${pkgs.util-linux}/bin/flock >/dev/null 2>&1; then
          exec {_lock_fd}>"$_lock_guard"
          if ! ${pkgs.util-linux}/bin/flock -n "$_lock_fd"; then
            _msg_fail "Another nrb --update-no-kernel is already running on this flake"
            exec {_lock_fd}>&-
            rm -f "$_lock_backup"
            return 1
          fi
        fi

        # Cleanup function — closes lock fd, removes temp files,
        # clears traps set by this block.
        _nrb_cleanup() {
          [[ -n "$_lock_fd" ]] && exec {_lock_fd}>&- 2>/dev/null
          rm -f "$_lock_guard" "$_lock_backup"
          trap - INT TERM HUP
        }
        # Restore function — called on abort to revert flake.lock
        _nrb_abort_restore() {
          [[ -f "$_lock_backup" ]] && cp "$_lock_backup" "$flake_dir/flake.lock" 2>/dev/null
          _nrb_cleanup
        }

        trap '_nrb_abort_restore' INT TERM HUP

        cp "$flake_dir/flake.lock" "$_lock_backup"

        # JSON-escape host-derived strings so paths containing spaces
        # or quotes never corrupt the inlined nix expression.
        _escaped_dir=$(printf '%s' "$flake_dir" | ${pkgs.jq}/bin/jq -Rr @json)
        _escaped_host=$(printf '%s' "$hostname" | ${pkgs.jq}/bin/jq -Rr @json)

        # Inline nix expression that returns the full {default+specs} map.
        _mk_kern_expr="
          let
            self = builtins.getFlake $_escaped_dir;
            host = self.nixosConfigurations.$_escaped_host;
            specs = host.config.specialisation or {};
          in
            { default = host.config.boot.kernelPackages.kernel.drvPath; }
            // builtins.mapAttrs
                 (_: s: s.configuration.boot.kernelPackages.kernel.drvPath)
                 specs
        "

        _mk_kern_map() {
          # Tee stderr to log for diagnosis. stdout (the JSON map) is
          # returned via command substitution; errors land in the log.
          nix --extra-experimental-features 'nix-command flakes' \
            eval --json --impure --option eval-cache false \
            --expr "$_mk_kern_expr" 2>>"$_eval_log"
        }
        _kern_map_eq() {
          # Canonicalise via jq sort so attribute order doesn't matter.
          [[ "$(echo "$1" | ${pkgs.jq}/bin/jq -cS .)" == "$(echo "$2" | ${pkgs.jq}/bin/jq -cS .)" ]]
        }
        # Check if a kernel derivation's output is cached on any
        # configured substituter. If cached, the "rebuild" is just a
        # download (~30s) not a source compile (~45-90 min).
        # Returns 0 (cached) or 1 (needs source build).
        _kern_is_cached() {
          local _drv="$1" _out_hash _sub
          # Resolve derivation → main output store path via nix-store
          # (more reliable than nix derivation show JSON parsing)
          local -a _outputs
          _outputs=( $(nix-store --query --outputs "$_drv" 2>/dev/null) )
          (( ''${#_outputs[@]} == 0 )) && return 1
          # Check the main output (first = "out", without -dev/-modules suffix)
          local _out_path="''${_outputs[1]}"
          _out_hash=$(basename "$_out_path" | cut -d- -f1)
          [[ -z "$_out_hash" ]] && return 1
          # Check each substituter for narinfo (HTTP HEAD, ~100ms each)
          for _sub in $(nix --extra-experimental-features 'nix-command flakes' \
            show-config 2>/dev/null | ${pkgs.gnugrep}/bin/grep '^substituters' \
            | sed 's/^substituters = //'); do
            if ${pkgs.curl}/bin/curl -sfI --connect-timeout 5 --max-time 10 "''${_sub}/''${_out_hash}.narinfo" >/dev/null 2>&1; then
              return 0
            fi
          done
          return 1
        }
        # Compare kernel maps accounting for cache availability.
        # Returns: 0 = safe (unchanged or cached), 1 = needs rebuild.
        # Sets _kern_cache_status with details for display.
        _kern_map_eq_or_cached() {
          local _base="$1" _new="$2"
          _kern_cache_status=""
          _kern_map_eq "$_base" "$_new" && return 0
          # Maps differ — check if changed kernels are all cached
          local -a _changed_keys _uncached
          _changed_keys=( $(${pkgs.jq}/bin/jq -nr --argjson a "$_base" --argjson b "$_new" '
            [$a | keys_unsorted[] | select($a[.] != $b[.])] | .[]') )
          for _k in "''${_changed_keys[@]}"; do
            local _new_drv=$(echo "$_new" | ${pkgs.jq}/bin/jq -r --arg k "$_k" '.[$k]')
            if ! _kern_is_cached "$_new_drv"; then
              _uncached+=("$_k")
            fi
          done
          if (( ''${#_uncached[@]} == 0 )); then
            _kern_cache_status="all cached (download only)"
            return 0
          fi
          _kern_cache_status="source rebuild: ''${_uncached[*]}"
          return 1
        }

        _msg_step "Autonomous kernel-safe update"
        _msg_dim "  1/4 reading baseline kernels (default + specialisations)..."
        local _baseline
        _baseline=$(_mk_kern_map)
        if [[ -z "$_baseline" ]]; then
          _msg_fail "Could not resolve baseline kernel drvPaths — aborting"
          _nrb_cleanup
          return 1
        fi
        echo "$_baseline" | ${pkgs.jq}/bin/jq -r \
          'to_entries[] | "      [\(.key)] \(.value | sub(".*/"; ""))"'

        _msg_dim "  2/4 running full flake update..."
        # Separate update from display — nix flake update emits to
        # stderr, so piping through grep with pipefail causes false
        # failures when no inputs changed (grep exit 1 → pipeline fail).
        local _update_out
        _update_out=$(nix flake update --flake "$flake_dir" 2>&1) || {
          _msg_fail "Full flake update failed"
          echo "$_update_out" >> "$_eval_log"
          _nrb_abort_restore
          return 1
        }
        echo "$_update_out" >> "$_eval_log"
        local _update_count
        _update_count=$(echo "$_update_out" | ${pkgs.gnugrep}/bin/grep -cE '(Updated|Added|Removed)' 2>/dev/null || true)
        _update_count=''${_update_count##*$'\n'}
        echo "$_update_out" | ${pkgs.gnugrep}/bin/grep -E '(Updated|Added|Removed)' | head -20 || true
        if [[ -n "$_update_count" ]] && (( _update_count > 20 )); then
          _msg_dim "  ... and $(( _update_count - 20 )) more"
        fi

        _msg_dim "  3/4 re-evaluating all kernels..."
        local _new
        _new=$(_mk_kern_map)
        if [[ -z "$_new" ]]; then
          _msg_fail "Post-update kernel eval failed — restoring baseline lock"
          _nrb_abort_restore
          return 1
        fi

        if _kern_map_eq_or_cached "$_baseline" "$_new"; then
          if [[ -n "$_kern_cache_status" ]]; then
            _msg_ok "  kernel changed but $_kern_cache_status — full update kept"
          else
            _msg_ok "  all kernels unchanged — full update kept"
          fi
          _nrb_cleanup
          echo ""
        else
          local _affected
          _affected=$(${pkgs.jq}/bin/jq -nr --argjson a "$_baseline" --argjson b "$_new" '
            [$a | keys_unsorted[] | select($a[.] != $b[.])] | join(",")')
          _msg_warn "  kernel(s) would rebuild: $_affected — isolating culprit inputs..."

          # Single-pass jq: load both locks as two documents, compute
          # name → rev for each, emit names whose rev differs. Replaces
          # the previous read-loop that spawned 2 × N jq processes.
          local -a _changed
          _changed=( "''${(@f)$(
            ${pkgs.jq}/bin/jq -rn --slurpfile a "$_lock_backup" --slurpfile b "$flake_dir/flake.lock" '
              def revs(lock): (lock.nodes.root.inputs // {})
                              | to_entries
                              | map({(.key): (lock.nodes[.value].locked.rev // "")})
                              | add;
              (revs($a[0])) as $oldR |
              (revs($b[0])) as $newR |
              ($oldR | keys[]) as $k |
              select($oldR[$k] != ($newR[$k] // "")) | $k
            '
          )}" )

          _changed=("''${(@)_changed:#}")
          _msg_dim "    ''${#_changed[@]} inputs moved; testing each in isolation..."

          local -a _safe _unsafe
          local _input _test _input_affected
          for _input in "''${_changed[@]}"; do
            cp "$_lock_backup" "$flake_dir/flake.lock"
            if ! nix flake update --flake "$flake_dir" "$_input" 2>>"$_eval_log"; then
              _unsafe+=("$_input(update-failed)")
              continue
            fi
            _test=$(_mk_kern_map)
            if [[ -z "$_test" ]]; then
              _unsafe+=("$_input(eval-failed)")
              printf "      %-30s eval failed — skipping\n" "$_input"
              continue
            fi
            if _kern_map_eq_or_cached "$_baseline" "$_test"; then
              _safe+=("$_input")
              if [[ -n "$_kern_cache_status" ]]; then
                printf "      %-30s ok (kernel cached)\n" "$_input"
              else
                printf "      %-30s ok\n" "$_input"
              fi
            else
              _input_affected=$(${pkgs.jq}/bin/jq -nr --argjson a "$_baseline" --argjson b "$_test" '
                [$a | keys_unsorted[] | select($a[.] != $b[.])] | join(",")')
              _unsafe+=("$_input")
              printf "      %-30s rebuilds: %s — skipping\n" "$_input" "$_input_affected"
            fi
          done

          _msg_dim "  4/4 applying safe updates..."
          cp "$_lock_backup" "$flake_dir/flake.lock"
          if (( ''${#_safe[@]} > 0 )); then
            local _batch_out
            _batch_out=$(nix flake update --flake "$flake_dir" "''${_safe[@]}" 2>&1) || {
              _msg_fail "Final update failed (see $_eval_log); lock restored to baseline"
              echo "$_batch_out" >> "$_eval_log"
              _nrb_abort_restore
              return 1
            }
            echo "$_batch_out" >> "$_eval_log"
            local _batch_count
            _batch_count=$(echo "$_batch_out" | ${pkgs.gnugrep}/bin/grep -cE '(Updated|Added|Removed)' 2>/dev/null || true)
            _batch_count=''${_batch_count##*$'\n'}
            echo "$_batch_out" | ${pkgs.gnugrep}/bin/grep -E '(Updated|Added|Removed)' | head -20 || true
            if [[ -n "$_batch_count" ]] && (( _batch_count > 20 )); then
              _msg_dim "  ... and $(( _batch_count - 20 )) more"
            fi
            _msg_ok "  updated ''${#_safe[@]} inputs"
            # Post-batch combinatorial safety check
            local _post_batch
            _post_batch=$(_mk_kern_map)
            if [[ -z "$_post_batch" ]]; then
              _msg_fail "Post-batch kernel eval failed — restoring baseline lock"
              _nrb_abort_restore
              return 1
            fi
            if ! _kern_map_eq_or_cached "$_baseline" "$_post_batch"; then
              _msg_warn "Batch combination triggers kernel rebuild — restoring baseline"
              _msg_dim "  Individual inputs were safe but combination is not"
              cp "$_lock_backup" "$flake_dir/flake.lock"
              _nrb_cleanup
              echo ""
            fi
          else
            _msg_dim "  no kernel-safe updates available"
          fi
          if (( ''${#_unsafe[@]} > 0 )); then
            _msg_warn "  skipped ''${#_unsafe[@]} kernel-triggering: ''${_unsafe[*]}"
            _msg_dim "    (run 'nrb --update' when you want the kernel to rebuild)"
          fi
          _nrb_cleanup
          echo ""
        fi

        # Report log only if it contains any content (tee'd stderr).
        if [[ -s "$_eval_log" ]]; then
          _msg_dim "  eval diagnostics: $_eval_log"
        fi
      fi

      # Dirty tree warning (check after update since --update modifies flake.lock)
      if command -v git &>/dev/null && [[ -d "$flake_dir/.git" ]]; then
        local dirty_files
        dirty_files=$(git -C "$flake_dir" diff --name-only -- flake.lock flake.nix 2>/dev/null)
        if [[ -n "$dirty_files" ]]; then
          _msg_warn "Flake inputs have uncommitted changes"
          echo "$dirty_files" | while IFS= read -r f; do
            [[ -n "$f" ]] && _msg_dim "  $f modified"
          done
          _msg_dim "  Nix may use cached evaluations. Commit first for reliable builds."
          echo ""
        fi
      fi

      # Pre-authenticate sudo (cache credentials before long build)
      if (( ! dry )); then
        if ! sudo -v 2>/dev/null; then
          _msg_fail "sudo authentication failed"
          return 1
        fi
      fi

      # Sudo keepalive — refresh credentials every 60s during build.
      # Cleanup via _nrb_kill_sudo, called explicitly on every exit
      # path instead of an EXIT trap (avoids overwriting the
      # update-section's trap chain).
      local _sudo_keepalive_pid=""
      _nrb_kill_sudo() {
        if [[ -n "$_sudo_keepalive_pid" ]]; then
          kill "$_sudo_keepalive_pid" 2>/dev/null
          wait "$_sudo_keepalive_pid" 2>/dev/null
        fi
        _sudo_keepalive_pid=""
      }
      if (( ! dry )); then
        ( trap 'exit 0' TERM INT HUP; while true; do sudo -v 2>/dev/null; sleep 60 & wait $!; done ) &
        _sudo_keepalive_pid=$!
        trap '_nrb_kill_sudo' INT TERM
      fi

      # Remote builder reachability check. Uses nix store info to test
      # connectivity via the daemon's SSH config (same keys as actual builds).
      # When all builders are unreachable, injects --builders "" so
      # nix skips SSH attempts entirely (avoids ~2min TCP timeout per derivation).
      local -a _jobs_override=()
      if [[ -f /etc/nix/machines ]] && [[ -s /etc/nix/machines ]]; then
        local -a _builder_uris=()
        local _line _uri
        while IFS= read -r _line; do
          [[ -z "$_line" || "$_line" == \#* ]] && continue
          _uri=''${_line%% *}
          [[ "$_uri" != ssh://* && "$_uri" != ssh-ng://* ]] && _uri="ssh://$_uri"
          [[ -n "$_uri" ]] && _builder_uris+=("$_uri")
        done < /etc/nix/machines

        local _any_reachable=0
        if (( ''${#_builder_uris[@]} > 0 )); then
          _msg_step "Checking remote builders..."
          for _uri in "''${_builder_uris[@]}"; do
            if timeout 15 nix store info --store "$_uri" 2>/dev/null; then
              _msg_dim "  $_uri reachable"
              _any_reachable=1
            else
              _msg_dim "  $_uri unreachable"
            fi
          done
        fi

        if (( ! _any_reachable )); then
          _msg_warn "All remote builders unreachable — building locally"
          _msg_dim "  Skipping remote to avoid SSH timeout delays."
          echo ""
          _jobs_override=(--builders "")
        fi
      fi

      # Build
      _msg_step "Building $flake_dir#nixosConfigurations.$hostname ..."
      local start_time=$SECONDS

      local build_path _build_rc=0
      local _build_out
      _build_out=$(mktemp -t nrb-build-XXXXXX) || {
        _msg_fail "Cannot create temp file for build output"
        _nrb_kill_sudo
        return 1
      }

      if command -v nom &>/dev/null; then
        nom build \
          "$flake_dir/.#nixosConfigurations.$hostname.config.system.build.toplevel" \
          --print-out-paths --no-link \
          "''${_jobs_override[@]}" $trace_flag \
          > "$_build_out" || _build_rc=$?
      else
        nix --extra-experimental-features 'nix-command flakes' \
          build "$flake_dir/.#nixosConfigurations.$hostname.config.system.build.toplevel" \
          --print-out-paths --no-link \
          "''${_jobs_override[@]}" $trace_flag \
          > "$_build_out" || _build_rc=$?
      fi

      local elapsed=$(( SECONDS - start_time ))

      if (( _build_rc != 0 )); then
        _msg_fail "Build failed! (''${elapsed}s)"
        rm -f "$_build_out"
        _nrb_kill_sudo
        return 1
      fi

      build_path=$(grep '^/nix/store/' "$_build_out" | tail -n1)
      rm -f "$_build_out"

      if [[ -z "$build_path" || ! -d "$build_path" ]]; then
        _msg_fail "Build produced no valid output path (''${elapsed}s)"
        _nrb_kill_sudo
        return 1
      fi

      _msg_ok "Build succeeded in ''${elapsed}s"
      # Bell on completion — useful when build takes 10+ min
      printf '\a'

      # System diff
      echo ""
      _msg_step "Changes compared to current system:"
      if command -v nvd &>/dev/null; then
        nvd diff /run/current-system "$build_path" 2>/dev/null || true
      else
        _msg_dim "  (nvd not installed — enable myModules.home.nvd for generation diffs)"
      fi

      # Kernel change detection
      local cur_kernel new_kernel needs_reboot=0
      cur_kernel=$(readlink -f /run/current-system/kernel 2>/dev/null || echo "")
      new_kernel=$(readlink -f "$build_path/kernel" 2>/dev/null || echo "")
      if [[ -n "$cur_kernel" && -n "$new_kernel" && "$cur_kernel" != "$new_kernel" ]]; then
        needs_reboot=1
        echo ""
        _msg_warn "Kernel changed!"
        _msg_dim "  Current: $(basename "$cur_kernel")"
        _msg_dim "  New:     $(basename "$new_kernel")"
      fi

      # Kernel module change detection — compare the resolved
      # kernel-modules store path (derivation hash differs whenever
      # the module set changes, including out-of-tree modules like
      # b43, zfs, virtualbox, ryzen-smu). Avoids fragile globs.
      local cur_mods_path new_mods_path
      cur_mods_path=$(readlink -f /run/current-system/kernel-modules 2>/dev/null || echo "")
      new_mods_path=$(readlink -f "$build_path/kernel-modules" 2>/dev/null || echo "")
      if [[ -n "$cur_mods_path" && -n "$new_mods_path" && "$cur_mods_path" != "$new_mods_path" ]]; then
        needs_reboot=1
        echo ""
        _msg_warn "Kernel modules changed:"

        # Per-module diff — enumerate with `find` (glob-safe) over the
        # modules tree. `-printf` is GNU-find specific; fall back to
        # `-exec basename` if missing (NixOS ships GNU findutils).
        local cur_list new_list
        cur_list=$(find "$cur_mods_path/lib/modules" -type f \
                     \( -name "*.ko" -o -name "*.ko.zst" -o -name "*.ko.xz" -o -name "*.ko.gz" \) \
                     -printf '%f\n' 2>/dev/null | sort -u)
        new_list=$(find "$new_mods_path/lib/modules" -type f \
                     \( -name "*.ko" -o -name "*.ko.zst" -o -name "*.ko.xz" -o -name "*.ko.gz" \) \
                     -printf '%f\n' 2>/dev/null | sort -u)

        if [[ -n "$cur_list" || -n "$new_list" ]]; then
          diff <(echo "$cur_list") <(echo "$new_list") 2>/dev/null \
            | grep '^[<>]' | while read -r line; do
              local mod="''${line#[<>] }"
              mod="''${mod%%.ko*}"
              case "$line" in
                \<*) _msg_dim "  - $mod (removed)" ;;
                \>*) _msg_dim "  + $mod (added/updated)" ;;
              esac
            done
        else
          _msg_dim "  (derivation hash changed — module tree rebuilt)"
        fi
      fi

      # Show specialisation info if any exist in the build
      if [[ -d "$build_path/specialisation" ]]; then
        local spec_count=$(ls "$build_path/specialisation" 2>/dev/null | wc -l)
        if (( spec_count > 0 )); then
          echo ""
          _msg_info "Boot variants ($spec_count specialisations):"
          for spec_dir in "$build_path/specialisation"/*/; do
            local spec_name=$(basename "$spec_dir")
            local spec_kernel=$(readlink -f "$spec_dir/kernel" 2>/dev/null || echo "")
            local spec_kname=""
            [[ -n "$spec_kernel" ]] && spec_kname=" ($(basename "$spec_kernel"))"
            _msg_dim "  + $spec_name$spec_kname"
          done
        fi
      fi

      # Dry run stops here
      if (( dry )); then
        echo ""
        _msg_info "Dry run — not activating."
        _msg_dim "  Built path: $build_path"
        return 0
      fi

      # Snapshot HM generation before switch
      local hm_gcroot="$HOME/.local/state/home-manager/gcroots/current-home"
      local hm_before
      hm_before=$(readlink "$hm_gcroot" 2>/dev/null || echo "")

      # Set system profile
      echo ""
      _msg_step "Setting system profile..."
      if ! sudo nrb-activate set-profile "$build_path"; then
        _msg_fail "Profile switch cancelled or failed!"
        _msg_dim "  Built path: $build_path"
        _msg_dim "  To activate manually:"
        _msg_dim "  sudo nrb-activate set-profile $build_path"
        _msg_dim "  sudo nrb-activate switch $build_path"
        _nrb_kill_sudo
        return 1
      fi

      # Activate
      local action="switch"
      if (( boot )); then
        action="boot"
        _msg_step "Activating for next boot..."
      else
        _msg_step "Activating new configuration..."
      fi
      local switch_rc=0
      sudo nrb-activate "$action" "$build_path" || switch_rc=$?
      case $switch_rc in
        0)  ;; # success
        2)  _msg_warn "Activation scripts had errors (non-fatal)"
            _msg_dim "  Some activation scripts failed. Check 'journalctl -b 0 | grep activate' for details." ;;
        100) _msg_warn "System requires reboot (init version changed)"
             needs_reboot=1 ;;
        *)  _msg_fail "Activation failed! (exit $switch_rc)"
            _msg_dim "  The system profile was set but activation did not complete."
            _msg_dim "  Rollback: sudo nixos-rebuild switch --rollback"
            _nrb_kill_sudo
            return 1 ;;
      esac

      # Post-switch verification
      local current_after
      current_after=$(readlink -f /run/current-system 2>/dev/null)
      if [[ "$action" == "switch" && "$current_after" != "$build_path" ]]; then
        _msg_fail "/run/current-system does not match the built path!"
        _msg_dim "  Expected: $build_path"
        _msg_dim "  Actual:   $current_after"
        _msg_dim "  Another switch may have raced. Rollback: sudo nixos-rebuild switch --rollback"
        _nrb_kill_sudo
        return 1
      fi

      # Generation info
      local gen
      gen=$(readlink /nix/var/nix/profiles/system | sed 's/system-\(.*\)-link/\1/')
      echo ""
      _msg_ok "Active generation: $gen"

      # Boot entry verification (--boot mode)
      if (( boot )); then
        local _boot_entry_found=0
        # systemd-boot: check /boot/loader/entries/ for this generation
        if [[ -d /boot/loader/entries ]]; then
          if ls /boot/loader/entries/nixos-generation-"$gen"[-.]*.conf 1>/dev/null 2>&1; then
            _boot_entry_found=1
            local _entry_count
            _entry_count=$(ls /boot/loader/entries/nixos-generation-"$gen"[-.]*.conf 2>/dev/null | wc -l)
            _msg_ok "Boot entry written ($_entry_count entries for generation $gen)"
          fi
        fi
        # grub: check /boot/grub/grub.cfg references this generation
        if [[ -f /boot/grub/grub.cfg ]] && grep -q "generation-$gen" /boot/grub/grub.cfg 2>/dev/null; then
          _boot_entry_found=1
          _msg_ok "GRUB entry written for generation $gen"
        fi
        if (( ! _boot_entry_found )); then
          _msg_warn "Could not verify boot entry for generation $gen"
          _msg_dim "  Check: ls /boot/loader/entries/ or cat /boot/grub/grub.cfg"
          _msg_dim "  System may boot into old generation until verified"
        fi
      fi

      # HM diff (compare home-files trees between new build vs current)
      if (( ! boot )); then
        # Find HM generation inside the new system build
        local hm_new
        hm_new=$(find "$build_path/etc/profiles/per-user" -name home-manager -type l 2>/dev/null | head -1)
        if [[ -n "$hm_new" ]]; then
          hm_new=$(readlink -f "$hm_new" 2>/dev/null)
        fi
        # Fall back to gcroot if we can't find it in the build
        if [[ -z "$hm_new" || ! -d "$hm_new" ]]; then
          local hm_wait=0
          while (( hm_wait < 8 )); do
            hm_new=$(readlink "$hm_gcroot" 2>/dev/null || echo "")
            [[ -n "$hm_new" && "$hm_new" != "$hm_before" ]] && break
            sleep 0.5
            (( hm_wait++ ))
          done
        fi
        if [[ -n "$hm_before" && -n "$hm_new" && "$hm_before" != "$hm_new" ]]; then
          if [[ -d "$hm_before/home-files" && -d "$hm_new/home-files" ]]; then
            echo ""
            _msg_info "Home Manager changes:"
            diff -rq "$hm_before/home-files" "$hm_new/home-files" 2>/dev/null | \
              sed 's|.*/home-files/|  |' | head -30
          fi
        else
          echo ""
          _msg_info "Home Manager: no change"
        fi
      fi

      # Reboot reminder (kernel or modules changed)
      if (( needs_reboot )); then
        echo ""
        _msg_warn "Reboot required for kernel/module changes!"
      fi

      # Regenerate module docs after successful switch (background, silent).
      # scripts/generate-docs.nix now returns a plain string (pure eval,
      # no derivation build) — use `nix eval --raw`, matching update-docs hook.
      if (( ! dry && ! boot )); then
        (cd "$flake_dir" && {
          nix eval --raw --impure --file scripts/generate-docs.nix markdown \
            > docs/OPTIONS.md.tmp 2>/dev/null \
            && mv -f docs/OPTIONS.md.tmp docs/OPTIONS.md
        } &) >/dev/null 2>&1
      fi

      _nrb_kill_sudo

      # Rollback hint
      echo ""
      _msg_dim "Rollback: sudo nixos-rebuild switch --rollback"
    }
  '';

  nrbCheck = ''
    nrb-check() {
      local flake_dir="''${FLAKE_DIR:-${flakeDir}}"
      local _jq="${pkgs.jq}/bin/jq"
      local trace_flag=""
      local configs_json name eval_output specs_json spec spec_output
      local -a config_names spec_names
      local total=0 passed=0 failed=0

      [[ "''${1:-}" == "--show-trace" ]] && trace_flag="--show-trace"

      echo "Checking all NixOS configurations in $flake_dir"
      echo ""

      # Discover all nixosConfigurations dynamically
      configs_json=$(nix --extra-experimental-features 'nix-command flakes' \
        eval "$flake_dir#nixosConfigurations" --apply 'x: builtins.attrNames x' --json 2>/dev/null)
      if [[ -z "$configs_json" || "$configs_json" == "[]" ]]; then
        echo "ERROR: No nixosConfigurations found in $flake_dir"
        return 1
      fi

      config_names=()
      while IFS= read -r name; do
        config_names+=("$name")
      done < <(echo "$configs_json" | $_jq -r '.[]')

      for name in "''${config_names[@]}"; do
        (( total++ ))
        printf "  %-30s " "$name"

        if eval_output=$(nix --extra-experimental-features 'nix-command flakes' \
          eval "$flake_dir#nixosConfigurations.$name.config.system.build.toplevel.drvPath" \
          $trace_flag 2>&1); then
          echo "OK"
          (( passed++ ))

          # Discover and individually evaluate each specialisation
          specs_json=$(nix --extra-experimental-features 'nix-command flakes' \
            eval "$flake_dir#nixosConfigurations.$name.config.specialisation" \
            --apply 'x: builtins.attrNames x' --json 2>/dev/null || echo "[]")

          if [[ "$specs_json" != "[]" ]]; then
            spec_names=()
            while IFS= read -r spec; do
              spec_names+=("$spec")
            done < <(echo "$specs_json" | $_jq -r '.[]')

            for spec in "''${spec_names[@]}"; do
              (( total++ ))
              printf "    %-26s " "+ $spec"
              if spec_output=$(nix --extra-experimental-features 'nix-command flakes' \
                eval "$flake_dir#nixosConfigurations.$name.config.specialisation.$spec.configuration.system.build.toplevel.drvPath" \
                $trace_flag 2>&1); then
                echo "OK"
                (( passed++ ))
              else
                echo "FAILED"
                (( failed++ ))
                echo "$spec_output" | tail -5 | sed 's/^/      /'
              fi
            done
          fi
        else
          echo "FAILED"
          (( failed++ ))
          echo "$eval_output" | tail -5 | sed 's/^/      /'
        fi
      done

      echo ""
      echo "Results: $passed/$total passed, $failed failed"
      (( failed == 0 ))
    }
  '';

  nrbInfo = ''
    nrb-info() {
      local flake_dir="''${FLAKE_DIR:-${flakeDir}}"
      local _jq="${pkgs.jq}/bin/jq"
      local hostname booted_spec="" gen hm_gen store_size
      local name marker specs spec smarker
      hostname=$(hostname)

      echo "NixOS System Info"
      echo "================="
      echo ""
      echo "  Hostname:     $hostname"
      echo "  Kernel:       $(uname -r)"
      echo "  NixOS:        $(nixos-version 2>/dev/null || echo 'unknown')"

      # Detect active specialisation from booted system
      if [[ -f /run/current-system/etc/nixos-tags ]]; then
        booted_spec=$(cat /run/current-system/etc/nixos-tags 2>/dev/null | head -1)
      elif [[ -L /run/booted-system/specialisation ]]; then
        booted_spec=$(basename "$(readlink /run/booted-system/specialisation)" 2>/dev/null)
      fi
      if [[ -n "$booted_spec" ]]; then
        echo "  Active spec:  $booted_spec"
      fi
      echo ""

      # Current generation
      gen=$(readlink /nix/var/nix/profiles/system | sed 's/system-\(.*\)-link/\1/')
      echo "  Generation:   $gen"

      # HM generation
      hm_gen=$(home-manager generations 2>/dev/null | head -1)
      if [[ -n "$hm_gen" ]]; then
        echo "  HM Gen:       $hm_gen"
      fi

      # Store size
      store_size=$(du -sh /nix/store 2>/dev/null | cut -f1)
      if [[ -n "$store_size" ]]; then
        echo "  Store size:   $store_size"
      fi
      echo ""

      # Available configs + specialisations
      echo "Configurations:"
      nix --extra-experimental-features 'nix-command flakes' \
        eval "$flake_dir#nixosConfigurations" --apply 'x: builtins.attrNames x' --json 2>/dev/null \
        | $_jq -r '.[]' | while read -r name; do
          marker=""
          [[ "$name" == "$hostname" ]] && marker="  (active)"
          echo "  $name$marker"

          # Show specialisations
          specs=$(nix --extra-experimental-features 'nix-command flakes' \
            eval "$flake_dir#nixosConfigurations.$name.config.specialisation" \
            --apply 'x: builtins.attrNames x' --json 2>/dev/null || echo "[]")
          if [[ "$specs" != "[]" ]]; then
            echo "$specs" | $_jq -r '.[]' | while read -r spec; do
              smarker=""
              [[ "$spec" == "$booted_spec" ]] && smarker="  (booted)"
              echo "    + $spec$smarker"
            done
          fi
        done
      echo ""

      # Recent generations
      echo "Recent generations:"
      sudo nix-env -p /nix/var/nix/profiles/system --list-generations 2>/dev/null | tail -5 | sed 's/^/  /'
    }
  '';
}
