{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # Zsh Configuration
  # ============================================================================
  programs.zsh = {
    enable = true;

    # Enable useful plugins
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # History configuration
    history = {
      size = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      share = true;
      save = 100000;
      extended = true;
      ignoreAllDups = true;
    };

    # Shell aliases
    shellAliases = {
      # Enhanced ls
      ll = "ls -alF --group-directories-first";
      l = "ls -CF --group-directories-first";
      ls = "ls --color=auto";

      # Colored output
      grep = "grep --color=auto";
      ip = "ip -color=auto";

      # System maintenance (cleans system generations, user generations, HM generations, optimizes store)
      gc = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo nix-store --optimize";
      lc = ''
        sudo dmesg -C
        sudo sh -c "journalctl --rotate && journalctl --vacuum-time=1s"
        sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} +
        sudo find /var/log -type f \( -name '*.log.*' -o -name '*.old' \) -exec truncate -s 0 {} +
        sudo systemctl restart systemd-journald.service
      '';

      # Better defaults
      cat = "bat --paging=never";

      # Typo fix
      "cd.." = "cd ..";
    };

    # Cached compinit — regenerate dump only every 24h
    completionInit = ''
      autoload -Uz compinit
      if [[ -n ''${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
        compinit
      else
        compinit -C
      fi
    '';

    # ============================================================================
    # Zsh Initialization & Custom Functions
    # ============================================================================
    initContent = ''
      # Zsh options
      setopt HIST_REDUCE_BLANKS
      setopt HIST_VERIFY
      setopt AUTO_MENU
      setopt COMPLETE_IN_WORD
      setopt ALWAYS_TO_END
      setopt NOTIFY
      setopt LONG_LIST_JOBS
      setopt AUTO_PUSHD
      setopt PUSHD_IGNORE_DUPS
      unsetopt AUTO_REMOVE_SLASH
      setopt EXTENDED_GLOB
      setopt NO_BEEP
      unsetopt FLOW_CONTROL

      # --------------------------------------------------------------------------
      # NixOS Build & Upgrade Helper
      # --------------------------------------------------------------------------

      nrb() {
        local trace_flag="" dry=0 boot=0 update=0 check=0 target=""
        local flake_dir="''${FLAKE_DIR:-$HOME/Documents/nix}"

        # Parse flags
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --trace)  trace_flag="--show-trace"; shift ;;
            --dry)    dry=1; shift ;;
            --boot)   boot=1; shift ;;
            --update) update=1; shift ;;
            --check)  check=1; shift ;;
            --host)
              if [[ -z "''${2:-}" || "$2" == --* ]]; then
                echo "ERROR: --host requires a hostname argument"
                return 1
              fi
              target="$2"; shift 2
              ;;
            --help|-h)
              echo "nrb — NixOS Rebuild Helper"
              echo ""
              echo "Usage: nrb [FLAGS]"
              echo ""
              echo "Flags:"
              echo "  --update     Update all flake inputs before building"
              echo "  --dry        Build + show diff, don't activate"
              echo "  --boot       Build + activate on next reboot (not immediately)"
              echo "  --trace      Show full Nix stack trace on errors"
              echo "  --check      Evaluate all configs without building (fast sanity check)"
              echo "  --host X     Build a specific nixosConfiguration (default: current hostname)"
              echo "  --list       Show all available configurations and specialisations"
              echo "  --help, -h   Show this help message"
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
                  marker=""
                  [[ "$name" == "$(hostname)" ]] && marker="  (current)"
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

        # --check: evaluate all configs without building
        if (( check )); then
          nrb-check $trace_flag
          return $?
        fi

        # Warn if building a config that doesn't match current hostname
        if [[ -n "$target" && "$target" != "$(hostname)" ]]; then
          echo " Building config '$hostname' (current host: $(hostname))"
          if (( ! dry && ! boot )); then
            echo " WARNING: Switching to a config with a different hostname!"
            echo "          Your hostname will change to '$hostname' after activation."
            echo ""
            read -q "?Continue? [y/N] " || { echo "\nAborted."; return 1; }
            echo ""
          fi
        fi

        # Update flake inputs
        if (( update )); then
          echo "Updating flake inputs in $flake_dir ..."
          if ! nix flake update --flake "$flake_dir"; then
            echo -e "\n Flake update failed!"
            return 1
          fi
          echo ""
        fi

        # Build
        echo "Building $flake_dir#nixosConfigurations.$hostname ..."
        local start_time=$SECONDS

        local build_path
        build_path=$(nix --extra-experimental-features 'nix-command flakes' \
          build "$flake_dir/.#nixosConfigurations.$hostname.config.system.build.toplevel" \
          --print-out-paths --no-link --option max-jobs "$(nproc)" \
          $trace_flag 2>&1 | tee /dev/stderr | grep '^/nix/store/' | tail -n1)

        local elapsed=$(( SECONDS - start_time ))

        if [[ -z "$build_path" || ! -d "$build_path" ]]; then
          echo -e "\n Build failed! (''${elapsed}s)"
          return 1
        fi

        echo -e "\n Build succeeded in ''${elapsed}s"

        # System diff
        echo -e "\n Changes compared to current system:"
        nvd diff /run/current-system "$build_path"

        # Kernel change detection
        local cur_kernel new_kernel
        cur_kernel=$(readlink -f /run/current-system/kernel 2>/dev/null || echo "")
        new_kernel=$(readlink -f "$build_path/kernel" 2>/dev/null || echo "")
        if [[ -n "$cur_kernel" && -n "$new_kernel" && "$cur_kernel" != "$new_kernel" ]]; then
          echo -e "\n Kernel changed!"
          echo "  Current: $(basename "$cur_kernel")"
          echo "  New:     $(basename "$new_kernel")"
          echo "  A reboot is required to run the new kernel."
        fi

        # Show specialisation info if any exist in the build
        if [[ -d "$build_path/specialisation" ]]; then
          local spec_count=$(ls "$build_path/specialisation" 2>/dev/null | wc -l)
          if (( spec_count > 0 )); then
            echo -e "\n Boot variants built ($spec_count specialisations):"
            for spec_dir in "$build_path/specialisation"/*/; do
              local spec_name=$(basename "$spec_dir")
              local spec_kernel=$(readlink -f "$spec_dir/kernel" 2>/dev/null || echo "")
              local spec_kname=""
              [[ -n "$spec_kernel" ]] && spec_kname=" ($(basename "$spec_kernel"))"
              echo "  + $spec_name$spec_kname"
            done
          fi
        fi

        # Dry run stops here
        if (( dry )); then
          echo -e "\n Dry run — not activating. Built path:"
          echo "  $build_path"
          return 0
        fi

        # Snapshot HM generation before switch
        local hm_gcroot="$HOME/.local/state/home-manager/gcroots/current-home"
        local hm_before
        hm_before=$(readlink "$hm_gcroot" 2>/dev/null || echo "")

        # Set system profile
        echo -e "\n Setting system profile..."
        sudo nix-env -p /nix/var/nix/profiles/system --set "$build_path"

        # Activate
        local action="switch"
        if (( boot )); then
          action="boot"
          echo " Activating for next boot..."
        else
          echo " Activating new configuration..."
        fi
        sudo "$build_path/bin/switch-to-configuration" "$action"

        # Generation info
        local gen
        gen=$(readlink /nix/var/nix/profiles/system | sed 's/system-\(.*\)-link/\1/')
        echo -e "\n Active generation: $gen"

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
            while (( hm_wait < 4 )); do
              hm_new=$(readlink "$hm_gcroot" 2>/dev/null || echo "")
              [[ -n "$hm_new" && "$hm_new" != "$hm_before" ]] && break
              sleep 0.5
              (( hm_wait++ ))
            done
          fi
          if [[ -n "$hm_before" && -n "$hm_new" && "$hm_before" != "$hm_new" ]]; then
            if [[ -d "$hm_before/home-files" && -d "$hm_new/home-files" ]]; then
              echo -e "\n Home Manager changes:"
              diff -rq "$hm_before/home-files" "$hm_new/home-files" 2>/dev/null | \
                sed 's|.*/home-files/|  |' | head -30
            fi
          else
            echo -e "\n Home Manager: no change"
          fi
        fi

        # Kernel reboot reminder
        if [[ -n "$cur_kernel" && -n "$new_kernel" && "$cur_kernel" != "$new_kernel" ]]; then
          echo -e "\n Remember to reboot for the new kernel!"
        fi

        # Regenerate module docs after successful switch (background, silent)
        if (( ! dry && ! boot )); then
          (cd "$flake_dir" && {
            local doc_path
            doc_path=$(nix-build scripts/generate-docs.nix --no-out-link --quiet 2>/dev/null) && \
            cp -f "$doc_path" docs/OPTIONS.md 2>/dev/null
          } &) >/dev/null 2>&1
        fi

        # Rollback hint
        echo -e "\n Rollback: sudo nixos-rebuild switch --rollback"
      }

      # --------------------------------------------------------------------------
      # Config Check — evaluate all flake configs + specialisations
      # --------------------------------------------------------------------------

      nrb-check() {
        local flake_dir="''${FLAKE_DIR:-$HOME/Documents/nix}"
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

      # --------------------------------------------------------------------------
      # System Info — show current NixOS state, generations, and key config
      # --------------------------------------------------------------------------

      nrb-info() {
        local flake_dir="''${FLAKE_DIR:-$HOME/Documents/nix}"
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
  };

}
