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
      gc = "sudo nix-collect-garbage -d && sudo nix-store --gc && sudo nix-store --optimize";
      lc = ''
        sudo dmesg -C
        sudo sh -c "journalctl --rotate && journalctl --vacuum-time=1s"
        sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} +
        sudo find /var/log -type f \( -name '*.log.*' -o -name '*.old' \) -exec truncate -s 0 {} +
        sudo systemctl restart systemd-journald.service
      ''; 

      # Typo fix
      "cd.." = "cd ..";
    };

    # Speed up zsh startup
    completionInit = "";

    # ============================================================================
    # Zsh Initialization & Custom Functions
    # ============================================================================
   initContent = ''
      # History configuration
      HISTSIZE=${toString config.programs.zsh.history.size}
      SAVEHIST=${toString config.programs.zsh.history.save}

      # Zsh options
      setopt APPEND_HISTORY
      setopt INC_APPEND_HISTORY
      setopt HIST_IGNORE_ALL_DUPS
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
      # NixOS Build & Upgrade Helpers
      # --------------------------------------------------------------------------

      # Internal: Build the NixOS system configuration
      _nix_build_system() {
        local traceFlag=""

        # Support --trace flag for debugging
        if [ "$1" = "--trace" ]; then
          traceFlag="--show-trace"
          shift
        fi

        # Build the system configuration
        local out
        out=$(sudo nix --extra-experimental-features 'nix-command flakes' \
          build "$HOME/Documents/nix/.#nixosConfigurations.$(hostname).config.system.build.toplevel" \
          --print-out-paths --no-link --option max-jobs "$(nproc)" \
          $traceFlag "$@")

        # Extract the store path from output
        local result
        result=$(echo "$out" | grep '^/nix/store/' | tail -n1)

        echo "$result"
      }

      # Internal: Show diff between current and new system
      _show_diff() {
        local result="$1"
        echo -e "\n📊 Changes compared to current system:"
        nvd diff /run/current-system "$result"
      }

      # Internal: Show Home Manager config file changes
      # Call with "before" to capture current state, "after" to show diff
      _hm_config_diff() {
        local state_file="/tmp/hm-config-snapshot"
        local config_dir="$HOME/.config"
        
        case "''${1:-}" in
          before)
            # Snapshot current symlinked config files (HM-managed ones point to /nix/store)
            find "$config_dir" -maxdepth 2 -type l -lname '/nix/store/*' 2>/dev/null | \
              while read -r link; do
                echo "$link|$(readlink -f "$link" 2>/dev/null)"
              done > "$state_file"
            ;;
          after)
            if [ ! -f "$state_file" ]; then
              echo -e "\n📝 Config changes: (no snapshot found)"
              return 0
            fi
            
            # Count files
            local old_count new_count
            old_count=$(wc -l < "$state_file")
            new_count=$(find "$config_dir" -maxdepth 2 -type l -lname '/nix/store/*' 2>/dev/null | wc -l)
            
            # Compare old symlinks with new ones
            local output=""
            
            while IFS='|' read -r old_link old_target; do
              if [ -L "$old_link" ]; then
                local new_target
                new_target=$(readlink -f "$old_link" 2>/dev/null)
                if [ "$old_target" != "$new_target" ]; then
                  output+="   ~ $(basename "$old_link") (changed)\n"
                fi
              else
                output+="   - $(basename "$old_link") (removed)\n"
              fi
            done < "$state_file"
            
            # Check for new files
            while read -r link; do
              if ! grep -q "^$link|" "$state_file" 2>/dev/null; then
                output+="   + $(basename "$link") (new)\n"
              fi
            done < <(find "$config_dir" -maxdepth 2 -type l -lname '/nix/store/*' 2>/dev/null)
            
            echo -e "\n📝 Config changes (Home Manager):"
            if [ -n "$output" ]; then
              echo -e "$output"
            else
              echo "   (no changes - $old_count files tracked)"
            fi
            
            rm -f "$state_file"
            ;;
        esac
      }

      # Build and activate new configuration
      upgrade() {
        local result
        result="$(_nix_build_system)"
        
        # Abort if build failed
        if [ -z "$result" ] || [ ! -d "$result" ]; then
          echo -e "\n❌ Build failed! Not switching."
          return 1
        fi
        
        _show_diff "$result"
        _hm_config_diff before
        
        # Update the system profile to the new generation
        echo -e "\n🔄 Updating system profile..."
        sudo nix-env -p /nix/var/nix/profiles/system --set "$result"
        
        # Activate the configuration
        echo -e "\n🔄 Activating new configuration..."
        sudo "$result/bin/switch-to-configuration" switch
        
        _hm_config_diff after
      }

      # Build and activate with trace output (for debugging)
      upgrade-trace() {
        local result
        result="$(_nix_build_system --trace)"
        
        # Abort if build failed
        if [ -z "$result" ] || [ ! -d "$result" ]; then
          echo -e "\n❌ Build failed! Not switching."
          return 1
        fi
        
        _show_diff "$result"
        _hm_config_diff before
        
        # Update the system profile to the new generation
        echo -e "\n🔄 Updating system profile..."
        sudo nix-env -p /nix/var/nix/profiles/system --set "$result"
        
        # Activate the configuration
        echo -e "\n🔄 Activating new configuration..."
        sudo "$result/bin/switch-to-configuration" switch
        
        _hm_config_diff after
      }

      # Build and show diff without activating
      build-test() {
        local result
        result="$(_nix_build_system)"
        
        # Abort if build failed
        if [ -z "$result" ] || [ ! -d "$result" ]; then
          echo -e "\n❌ Build failed!"
          return 1
        fi
        
        echo -e "\n📊 Changes (if you were to switch):"
        nvd diff /run/current-system "$result"
      }

      # Alias for upgrade (alternative name)
      rebuild() {
        local result
        result="$(_nix_build_system)"
        
        # Abort if build failed
        if [ -z "$result" ] || [ ! -d "$result" ]; then
          echo -e "\n❌ Build failed! Not switching."
          return 1
        fi
        
        _show_diff "$result"
        
        # Update the system profile to the new generation
        echo -e "\n🔄 Updating system profile..."
        sudo nix-env -p /nix/var/nix/profiles/system --set "$result"
        
        # Activate the configuration
        echo -e "\n🔄 Activating new configuration..."
        sudo "$result/bin/switch-to-configuration" switch
      }

      # Rebuild with trace output
      rebuild-trace() {
        local result
        result="$(_nix_build_system --trace)"
        
        # Abort if build failed
        if [ -z "$result" ] || [ ! -d "$result" ]; then
          echo -e "\n❌ Build failed! Not switching."
          return 1
        fi
        
        _show_diff "$result"
        
        # Update the system profile to the new generation
        echo -e "\n🔄 Updating system profile..."
        sudo nix-env -p /nix/var/nix/profiles/system --set "$result"
        
        # Activate the configuration
        echo -e "\n🔄 Activating new configuration..."
        sudo "$result/bin/switch-to-configuration" switch
      }
    '';
  };
}
