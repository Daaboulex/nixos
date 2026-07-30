# zsh — Zsh shell with custom functions, aliases, and theme-aware colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.zsh;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
  nrbFns = import ./nrb-functions.nix {
    inherit pkgs;
    inherit (cfg) flakeDir;
  };
  # scat <file> -- pretty-view a ROOT-owned file. sudo does only the read
  # (sudo bypasses shell aliases, and bat is a user package not in root's
  # PATH); bat highlights it as you, --file-name gives it the syntax from the
  # name without needing read access. Only when the bat module is enabled.
  scatFn = lib.optionalString config.myModules.home.bat.enable ''
    scat() {
      [[ -z "$1" ]] && { print -u2 "usage: scat <root-owned-file>"; return 1; }
      sudo cat -- "$1" | bat --paging=never --file-name="$1"
    }
  '';
in
{
  options.myModules.home.zsh = {
    enable = lib.mkEnableOption "Zsh shell with custom functions and aliases";
    settings = myLib.mkSettingsOption { };
    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Documents/nix";
      description = "Path to the NixOS flake directory used by nrb, nrb-check, and nrb-info.";
    };
  };

  config = lib.mkIf cfg.enable {
    # bwrap compatibility — Claude Code's bubblewrap sandbox can't bind-mount
    # nix-store symlinks. Replace ~/.zshenv symlink with a regular file copy.
    home.activation.makeZshenvMutable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      zshenv="$HOME/.zshenv"
      if [ -L "$zshenv" ]; then
        target=$(readlink -f "$zshenv")
        if [ -f "$target" ]; then
          run rm "$zshenv"
          run cp "$target" "$zshenv"
          run chmod 644 "$zshenv"
        fi
      fi
    '';

    # Zsh Configuration
    programs.zsh = myLib.mergeSettings {
      defaults = {
        enable = true;
        defaultKeymap = lib.mkDefault "viins"; # vi-mode; HM emits `bindkey -v` before plugin/integration binds so they land in the vi keymap (order-safe)

        # Enable useful plugins
        autosuggestion = {
          enable = lib.mkDefault true;
          highlight = lib.mkDefault (if hasTheme then "fg=${c.comment}" else "fg=8");
        };
        enableCompletion = lib.mkDefault true;
        syntaxHighlighting.enable = lib.mkDefault true;

        # Extra plugins — loaded after built-in ones
        plugins = [
          {
            name = "fzf-tab";
            src = pkgs.zsh-fzf-tab + "/share/fzf-tab";
          }
          {
            name = "nix-zsh-completions";
            src = pkgs.nix-zsh-completions + "/share/zsh/plugins/nix";
          }
          {
            name = "zsh-history-substring-search";
            src = pkgs.zsh-history-substring-search + "/share/zsh-history-substring-search";
          }
          {
            name = "zsh-autopair";
            src = pkgs.zsh-autopair + "/share/zsh/zsh-autopair";
          }
        ];

        # History configuration
        history = {
          size = lib.mkDefault 100000;
          path = lib.mkDefault "${config.xdg.stateHome}/zsh/history";
          share = lib.mkDefault true;
          save = lib.mkDefault 100000;
          extended = lib.mkDefault true;
          ignoreAllDups = lib.mkDefault true;
        };

        # Shell aliases (no mkDefault — attrsOf merges at equal priority,
        # but mkDefault on the whole attrset loses to any normal-priority definition)
        shellAliases = {
          # Colored output
          ip = "ip -color=auto";

          # Colored output
          grep = "grep --color=auto";

          # Glob cleanups carry (N): an empty match must expand to nothing --
          # a bare unmatched glob aborts the whole remaining alias body (zsh NOMATCH).
          lc = ''
            echo "── Logs ──"
            sudo dmesg -C
            sudo sh -c "journalctl --rotate && journalctl --vacuum-time=1s"
            sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} +
            sudo find /var/log -type f \( -name '*.log.*' -o -name '*.old' \) -exec truncate -s 0 {} +
            sudo rm -rf /nix/var/log/nix/drvs/ 2>/dev/null
            sudo systemctl restart systemd-journald.service

            echo "── Caches ──"
            rm -rf "$HOME/.cache/nix/"eval-cache-*(N) 2>/dev/null
            ${pkgs.flatpak}/bin/flatpak uninstall --unused -y 2>/dev/null || true

            echo "── Trash ──"
            ${pkgs.glib.bin}/bin/gio trash --empty 2>/dev/null || rm -rf "$HOME/.local/share/Trash/"*(N) 2>/dev/null

            echo "── Syncthing old versions ──"
            find "$HOME" -maxdepth 3 -name ".stversions" -type d -exec rm -rf {} + 2>/dev/null

            echo "── Done ──"
            command df -h /
          '';

          # Typo fix
          "cd.." = "cd ..";
        }
        # `cat` → bat only when the bat module is enabled (guarded cross-module
        # ref — falls back to plain cat otherwise; AUDIT.md §19).
        // lib.optionalAttrs config.myModules.home.bat.enable {
          cat = "bat --paging=never";
        };

        # Cached compinit — regenerate dump only every 24h
        completionInit = lib.mkDefault ''
          autoload -Uz compinit
          if [[ -n ''${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
            compinit
          else
            compinit -C
          fi
        '';

        # Zsh Initialization & Custom Functions
        initContent = ''
          # --------------------------------------------------------------------------
          # Quality-of-life widgets
          # --------------------------------------------------------------------------

          # Double-tap ESC to prepend sudo to current or previous command
          sudo-command-line() {
            [[ -z $BUFFER ]] && zle up-history
            if [[ $BUFFER == sudo\ * ]]; then
              LBUFFER="''${LBUFFER#sudo }"
            else
              LBUFFER="sudo $LBUFFER"
            fi
          }
          zle -N sudo-command-line
          bindkey "\e\e" sudo-command-line

          # --------------------------------------------------------------------------
          # Vi-mode (enabled order-safely via programs.zsh.defaultKeymap = "viins")
          # --------------------------------------------------------------------------

          # Backspace must delete past the insert point (vi insert keymap won't by default)
          bindkey '^?' backward-delete-char
          bindkey '^H' backward-delete-char

          # ESC->normal latency vs multi-key (gg, ci", dd) reliability tradeoff; units are
          # hundredths of a second. 20 (=200ms) is the documented sweet spot — lower for a
          # snappier ESC, raise if multi-key vicmd sequences misfire. (1 broke ESC-ESC sudo.)
          KEYTIMEOUT=20

          # Cursor shape changes per mode (beam=insert, block=normal)
          zle-keymap-select() {
            case $KEYMAP in
              vicmd)      print -n '\e[2 q' ;; # block cursor
              viins|main) print -n '\e[6 q' ;; # beam cursor
            esac
            zle reset-prompt   # refresh the Starship insert/normal indicator on mode switch
          }
          zle -N zle-keymap-select
          zle-line-init() { print -n '\e[6 q' }  # beam on new prompt
          zle -N zle-line-init

          # History substring search — Up/Down filter by what you typed
          bindkey '^[[A' history-substring-search-up
          bindkey '^[[B' history-substring-search-down
          bindkey -M vicmd 'k' history-substring-search-up
          bindkey -M vicmd 'j' history-substring-search-down

          # --------------------------------------------------------------------------
          # Self-documentation: discover your own shell surface. Named commands (work
          # regardless of zellij keybind state); Tab/fzf-tab already self-documents
          # completions and atuin Ctrl-R the history.
          #   cmds  fuzzy-browse aliases (definition shown inline) + functions; Enter
          #         pushes the chosen name to the prompt.
          #   keys  fuzzy-browse keybindings.
          # --------------------------------------------------------------------------
          cmds() {
            local sel k v
            # Flatten each alias body to one line: a multi-line alias (lc) would
            # otherwise scatter its body across the picker as bogus entries.
            sel=$( {
                for k v in "''${(@kv)aliases}"; do print -r -- "$k=''${v//$'\n'/; }"; done
                print -l -- ''${(k)functions:#_*}
              } | sort \
              | fzf --prompt='cmd> ' --height=70% --layout=reverse ) || return
            print -z -- "''${sel%%[ =]*} "
          }
          keys() {
            bindkey -L | fzf --prompt='key> ' --height=70% --layout=reverse --tac --no-sort
          }
          ${scatFn}

          # --------------------------------------------------------------------------
          # Zsh options
          # --------------------------------------------------------------------------
          setopt HIST_REDUCE_BLANKS
          setopt HIST_VERIFY
          setopt HIST_IGNORE_SPACE       # commands starting with space are not recorded
          setopt AUTO_MENU
          setopt COMPLETE_IN_WORD
          setopt ALWAYS_TO_END
          setopt NOTIFY
          setopt LONG_LIST_JOBS
          setopt AUTO_PUSHD
          setopt PUSHD_IGNORE_DUPS
          setopt PUSHD_MINUS             # cd +N feels natural (most recent = lowest number)
          unsetopt AUTO_REMOVE_SLASH
          setopt EXTENDED_GLOB
          setopt GLOB_DOTS               # globs match dotfiles without explicit .*
          setopt INTERACTIVE_COMMENTS    # allow # comments in interactive shell
          setopt COMBINING_CHARS         # proper Unicode combining character rendering
          setopt NO_BEEP
          unsetopt FLOW_CONTROL

          # --------------------------------------------------------------------------
          # Completion styling
          # --------------------------------------------------------------------------
          zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'  # case-insensitive + partial-word
          zstyle ':completion:*' menu no                                      # let fzf-tab capture completion (menu select suppresses it)
          zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"           # colorized file completions
          zstyle ':completion:*' group-name '''                               # group completions by type
          zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'     # group headers
          zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'  # no-match message
          ${lib.optionalString config.myModules.home.eza.enable ''
            zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always --icons --level=2 $realpath 2>/dev/null'
            zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza --tree --color=always --icons --level=2 $realpath 2>/dev/null'
          ''}

          ${lib.optionalString hasTheme ''
            # --------------------------------------------------------------------------
            # Breeze Dark syntax highlighting (wired to myModules.home.theme)
            # --------------------------------------------------------------------------
            typeset -gA ZSH_HIGHLIGHT_STYLES
            ZSH_HIGHLIGHT_STYLES[default]='fg=${c.foreground}'
            ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=${c.red},bold'
            ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=${c.blue}'
            ZSH_HIGHLIGHT_STYLES[alias]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[builtin]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[function]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[command]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[precommand]='fg=${c.green},underline'
            ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[path]='fg=${c.blue},underline'
            ZSH_HIGHLIGHT_STYLES[globbing]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=${c.blue-alt}'
            ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=${c.blue-alt}'
            ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=${c.green}'
            ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[assign]='fg=${c.foreground}'
            ZSH_HIGHLIGHT_STYLES[redirection]='fg=${c.orange}'
            ZSH_HIGHLIGHT_STYLES[comment]='fg=${c.comment}'
            ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=${c.foreground-dim}'
            ZSH_HIGHLIGHT_STYLES[arg0]='fg=${c.green}'
          ''}

          # --------------------------------------------------------------------------
          # NixOS Build & Upgrade Helper + Config Check + System Info
          # Functions extracted to nrb-functions.nix for testability.
          # --------------------------------------------------------------------------

          ${nrbFns.nrb}

          ${nrbFns.nrbCheck}

          ${nrbFns.nrbInfo}

          # --------------------------------------------------------------------------
          # gc -- reclaim disk. Bare `gc` runs the SAFE policy that lives once in
          # programs.nh.clean (parts/nix/nix.nix): it triggers that same nh-clean
          # service, which passes --no-gcroots so NO direnv/devenv/nix-shell root is
          # ever pruned (nothing rebuilds). The service is Type=oneshot and logs only
          # to the journal, so the blocking start alone shows nothing for minutes;
          # gc live-streams that run's journal lines to the terminal instead.
          # `gc --deep` opts into pruning gcroots older than the 7d window to reclaim
          # stale project shells, and asks first (nh --ask) so you see exactly what
          # goes. Inspect a past run: journalctl -u nh-clean.
          # --------------------------------------------------------------------------
          gc() {
            setopt local_options no_monitor
            case "''${1:-}" in
              "")
                local _since _jpid _rc
                _since=$(date '+%Y-%m-%d %H:%M:%S')
                journalctl -u nh-clean.service --since "$_since" -f -o cat &
                _jpid=$!
                trap 'kill "$_jpid" 2>/dev/null; trap - INT TERM; return 130' INT TERM
                sudo systemctl start nh-clean.service
                _rc=$?
                sleep 1   # let the follower flush the run's final journal lines
                trap - INT TERM
                kill "$_jpid" 2>/dev/null
                wait "$_jpid" 2>/dev/null
                return $_rc
                ;;
              --deep)
                # Drops --no-gcroots so direnv/devShell roots >7d are collected;
                # --keep-since 7d still shields shells used this week and --keep 5
                # keeps rollback generations. Retention mirrors programs.nh.clean.
                sudo nh clean all --keep 5 --keep-since 7d --ask
                ;;
              *)
                print -u2 "gc: unknown option ''${1:-} (use: gc | gc --deep)"
                return 2
                ;;
            esac
          }

        '';
      };
      overrides = cfg.settings;
    };
  };
}
