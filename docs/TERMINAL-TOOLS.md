# Terminal Tools Guide

Shell environment, tools, and their integration.

**See also:** [PACKAGES.md](PACKAGES.md) for custom-built packages, [TERMINAL-TOOLS-INVENTORY.md](TERMINAL-TOOLS-INVENTORY.md) for the full catalog.

## How It All Fits Together

```text
┌─────────────────────────────────────────────────────────────────┐
│  ZELLIJ (terminal workspace)                                    │
│  Tabs, splits, floating panes, session persistence              │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐ │
│  │  ZSH (shell)         │  │  NEOVIM (editor)                 │ │
│  │  ├─ starship prompt  │  │  ├─ telescope (fuzzy finder)     │ │
│  │  ├─ fzf-tab complete │  │  │   ├─ fd (file finding)        │ │
│  │  ├─ autosuggestions   │  │  │   └─ ripgrep (grep)          │ │
│  │  └─ sudo ESC-ESC     │  │  ├─ LSP (nixd, bashls)          │ │
│  │                      │  │  ├─ format-on-save (conform)     │ │
│  │  Tools in shell:     │  │  ├─ gitsigns (gutter markers)    │ │
│  │  ├─ bat (cat)        │  │  ├─ which-key (Space → popup)    │ │
│  │  ├─ eza (ls)         │  │  ├─ Space gl → lazygit           │ │
│  │  ├─ ripgrep (grep)   │  │  └─ Space fy → yazi              │ │
│  │  ├─ fd (find)        │  │                                  │ │
│  │  ├─ zoxide (cd)      │  └──────────────────────────────────┘ │
│  │  ├─ delta (git diff) │  ┌──────────────────────────────────┐ │
│  │  ├─ jq (JSON)        │  │  BTOP (system monitor)           │ │
│  │  └─ y → yazi (files) │  │  AMD GPU-aware, theme-matched    │ │
│  └──────────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

Theme module (breeze-dark) ──► zsh, starship, fzf, bat, neovim,
                               lazygit, btop, yazi, konsole, delta,
                               zellij (all share same color palette)
```

#### zsh — Your Shell

Everything starts here. Configured with smart defaults.

| Feature                         | How                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------ |
| Tab complete with fuzzy preview | Just press Tab — fzf-tab shows matches with previews                                 |
| Search command history          | **Ctrl+R** — fuzzy search through 100K history entries                               |
| Find files                      | **Ctrl+T** — ripgrep-powered file picker with bat syntax preview                     |
| Jump to directory               | **Alt+C** — fd-powered directory picker with eza tree preview                        |
| Prepend sudo                    | **ESC ESC** — double-tap Escape to toggle sudo on current line                       |
| Fix typo                        | `cd..` auto-corrects to `cd ..`                                                      |
| Colored cat                     | `cat file.nix` is aliased to bat with syntax highlighting                            |
| Rebuild NixOS                   | `nrb` to build+switch, `nrb --dry` to preview, `nrb --update` to update inputs first |
| Garbage collect                 | `gc` cleans system + user generations + optimizes store                              |

See [TERMINAL-TOOLS-INVENTORY.md](TERMINAL-TOOLS-INVENTORY.md) for the full tool catalog.
