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
  nrbFns = import ./nrb-functions.nix { inherit pkgs; flakeDir = cfg.flakeDir; };
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
    # ============================================================================
    # bwrap compatibility — Claude Code's bubblewrap sandbox can't bind-mount
    # nix-store symlinks. Replace ~/.zshenv symlink with a regular file copy.
    # ============================================================================
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

    # ============================================================================
    # Zsh Configuration
    # ============================================================================
    programs.zsh = myLib.mergeSettings {
      defaults = {
        enable = true;

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
          path = lib.mkDefault "${config.home.homeDirectory}/.zsh_history";
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
        completionInit = lib.mkDefault ''
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
          # Vi-mode enhancements
          # --------------------------------------------------------------------------

          # Allow backspace to merge lines
          bindkey '^?' backward-delete-char
          bindkey '^H' backward-delete-char

          # Instant ESC response (default 400ms is sluggish)
          KEYTIMEOUT=1

          # Cursor shape changes per mode (beam=insert, block=normal)
          zle-keymap-select() {
            case $KEYMAP in
              vicmd)      print -n '\e[2 q' ;; # block cursor
              viins|main) print -n '\e[6 q' ;; # beam cursor
            esac
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
          zstyle ':completion:*' menu select                                  # arrow-key menu selection
          zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"           # colorized file completions
          zstyle ':completion:*' group-name '''                               # group completions by type
          zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'     # group headers
          zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'  # no-match message
          zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always --icons --level=2 $realpath 2>/dev/null'
          zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza --tree --color=always --icons --level=2 $realpath 2>/dev/null'

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

        '';
      };
      overrides = cfg.settings;
    };
  };
}
