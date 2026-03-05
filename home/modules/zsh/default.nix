{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Starship Prompt - Modern shell prompt
  # ============================================================================
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;

      # Classic "user@host" format with modern styling
      username = {
        show_always = true;
        style_user = "bold blue";
        format = "[$user]($style)@";
      };

      hostname = {
        ssh_only = false;
        style = "bold blue";
        format = "[$hostname]($style) ";
      };
    };
  };

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

      # System maintenance
      gc = "sudo nix-collect-garbage -d && sudo nix-store --optimize";
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
        local trace_flag="" dry=0 boot=0 update=0
        local flake_dir="''${FLAKE_DIR:-$HOME/Documents/nix}"
        local hostname
        hostname=$(hostname)

        # Parse flags
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --trace)  trace_flag="--show-trace"; shift ;;
            --dry)    dry=1; shift ;;
            --boot)   boot=1; shift ;;
            --update) update=1; shift ;;
            *)        echo "Usage: nrb [--trace] [--dry] [--boot] [--update]"; return 1 ;;
          esac
        done

        # Update flake inputs
        if (( update )); then
          echo "Updating flake inputs in $flake_dir ..."
          nix flake update --flake "$flake_dir"
          if [[ $? -ne 0 ]]; then
            echo -e "\n Flake update failed!"
            return 1
          fi
          echo ""
        fi

        # Build
        echo "Building $flake_dir#nixosConfigurations.$hostname ..."
        local start_time=$SECONDS

        local result
        result=$(nix --extra-experimental-features 'nix-command flakes' \
          build "$flake_dir/.#nixosConfigurations.$hostname.config.system.build.toplevel" \
          --print-out-paths --no-link --option max-jobs "$(nproc)" \
          $trace_flag 2>&1 | tee /dev/stderr | grep '^/nix/store/' | tail -n1)

        local elapsed=$(( SECONDS - start_time ))

        if [[ -z "$result" || ! -d "$result" ]]; then
          echo -e "\n Build failed! (''${elapsed}s)"
          return 1
        fi

        echo -e "\n Build succeeded in ''${elapsed}s"

        # System diff
        echo -e "\n Changes compared to current system:"
        nvd diff /run/current-system "$result"

        # Kernel change detection
        local cur_kernel new_kernel
        cur_kernel=$(readlink -f /run/current-system/kernel 2>/dev/null || echo "")
        new_kernel=$(readlink -f "$result/kernel" 2>/dev/null || echo "")
        if [[ -n "$cur_kernel" && -n "$new_kernel" && "$cur_kernel" != "$new_kernel" ]]; then
          echo -e "\n Kernel changed!"
          echo "  Current: $(basename "$cur_kernel")"
          echo "  New:     $(basename "$new_kernel")"
          echo "  A reboot is required to run the new kernel."
        fi

        # Dry run stops here
        if (( dry )); then
          echo -e "\n Dry run — not activating. Built path:"
          echo "  $result"
          return 0
        fi

        # Snapshot HM generation before switch
        local hm_gcroot="$HOME/.local/state/home-manager/gcroots/current-home"
        local hm_before
        hm_before=$(readlink "$hm_gcroot" 2>/dev/null || echo "")

        # Set system profile
        echo -e "\n Setting system profile..."
        sudo nix-env -p /nix/var/nix/profiles/system --set "$result"

        # Activate
        local action="switch"
        if (( boot )); then
          action="boot"
          echo " Activating for next boot..."
        else
          echo " Activating new configuration..."
        fi
        sudo "$result/bin/switch-to-configuration" "$action"

        # Generation info
        local gen
        gen=$(readlink /nix/var/nix/profiles/system | sed 's/system-\(.*\)-link/\1/')
        echo -e "\n Active generation: $gen"

        # HM diff (compare home-files trees between new build vs current)
        if (( ! boot )); then
          # Find HM generation inside the new system build
          local hm_new
          hm_new=$(find "$result/etc/profiles/per-user" -name home-manager -type l 2>/dev/null | head -1)
          if [[ -n "$hm_new" ]]; then
            hm_new=$(readlink -f "$hm_new" 2>/dev/null)
          fi
          # Fall back to gcroot if we can't find it in the build
          if [[ -z "$hm_new" || ! -d "$hm_new" ]]; then
            # Brief wait for gcroot to update, then check
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
            result=$(nix-build scripts/generate-docs.nix --no-out-link --quiet 2>/dev/null) && \
            cp -f "$result" docs/OPTIONS.md 2>/dev/null
          } &) >/dev/null 2>&1
        fi

        # Rollback hint
        echo -e "\n Rollback: sudo nixos-rebuild switch --rollback"
      }

    '';
  };

  # ============================================================================
  # Shell Tool Integrations
  # ============================================================================

  # Smarter cd — learns frequent directories (use `z` instead of `cd`)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Fuzzy finder — Ctrl+R history, Ctrl+T files, Alt+C directories
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Per-directory environments — auto-loads .envrc / shell.nix
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Syntax-highlighted cat replacement
  programs.bat = {
    enable = true;
  };
}
