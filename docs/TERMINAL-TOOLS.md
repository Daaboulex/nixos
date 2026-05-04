# Terminal Tools Guide

Everything installed, how it connects, and how to use it.

## How It All Fits Together

```
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

## Tool-by-Tool Reference

### Shell Environment (always active)

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

#### starship — Prompt

Shows current directory, git branch/status, nix shell indicator, time. Themed with breeze-dark palette. No config needed — just works.

#### zoxide — Smart cd

Learns which directories you visit. After visiting `~/Documents/nix` a few times:

```bash
z nix        # jumps to ~/Documents/nix from anywhere
z doc        # jumps to ~/Documents (most-used match)
zi           # interactive picker with fzf
```

### File Viewing & Manipulation

#### bat — Syntax-Highlighted cat

```bash
cat file.nix          # aliased to bat — syntax colors, line numbers
bat --diff file.nix   # show git diff inline
man nix               # man pages rendered with bat colors (MANPAGER)
```

Also powers: fzf Ctrl+T preview, delta syntax highlighting.

#### eza — Modern ls

```bash
ls                    # aliased to eza — icons, git status, colors
ls -la                # detailed view with permissions
ls --tree             # tree view
```

Also powers: fzf Alt+C directory preview.

#### ripgrep — Fast grep

```bash
rg "pattern"          # search all files recursively (respects .gitignore)
rg "pattern" -t nix   # search only .nix files
rg -i "todo"          # case-insensitive
```

Also powers: fzf Ctrl+T file listing, neovim telescope live grep.

#### fd — Fast find

```bash
fd "*.nix"            # find all .nix files
fd -t d               # find directories only
fd -H                 # include hidden files
```

Also powers: fzf Alt+C directory listing, neovim telescope file finding.

#### yazi — File Manager

```bash
y                     # open yazi (syncs working directory on exit)
y ~/Documents         # open in specific directory
```

Inside yazi: `l` to enter/open, `h` to go up, `F` to filter, `/` to search.
Integrates with zoxide (learns directories you visit).
In neovim: **Space fy** opens yazi in current file's directory.

#### sd — Find and Replace (sed alternative)

```bash
sd 'old' 'new' file.nix         # replace in file
sd 'old' 'new' *.nix            # replace in multiple files
fd -e nix | xargs sd 'old' 'new' # replace across entire project
```

#### glow — Markdown Viewer

```bash
glow README.md        # render markdown beautifully in terminal
glow                  # browse all markdown files in current directory
```

#### csvlens — CSV Viewer

```bash
csvlens data.csv      # interactive spreadsheet view with columns
```

#### chafa — Images in Terminal

```bash
chafa image.png       # display image in terminal using Unicode
```

### Development

#### neovim — Editor/IDE

```bash
nvim file.nix         # open file
```

| Key              | What it does                        |
| ---------------- | ----------------------------------- |
| **Space** (wait) | Shows ALL keybindings via which-key |
| **Space ff**     | Find files (fd-powered, fast)       |
| **Space fg**     | Live grep (ripgrep-powered)         |
| **Space fy**     | Open yazi file manager              |
| **Space gl**     | Open lazygit                        |
| **Space ld**     | Go to definition                    |
| **Space lr**     | Find references                     |
| **Space ln**     | Rename symbol                       |
| **Space la**     | Code action                         |
| **Space lf**     | Format buffer                       |
| **Space gs**     | Stage git hunk                      |
| **Space gb**     | Blame line                          |
| **Space ?**      | Full cheat sheet                    |

LSP: **nixd** (Nix with option completion), **bashls** (shell scripts).
Format on save: nixfmt, stylua, shfmt.

#### git + delta — Version Control

```bash
git diff              # syntax-highlighted diffs with word-level changes
git log -p            # commit history with highlighted patches
git blame file.nix    # annotated blame with colors
```

Delta is automatic — configured as git's pager. Uses bat's syntax themes and breeze-dark line number colors.

#### lazygit — Visual Git UI

```bash
lazygit               # full git TUI: stage, commit, push, rebase
```

Also accessible from neovim: **Space gl**.

#### gh — GitHub CLI

```bash
gh pr create          # create pull request
gh pr list            # list PRs
gh issue list         # list issues
gh api /repos/NixOS/nixpkgs | jq '.stargazers_count'  # API access
```

#### direnv — Auto-Environments

```bash
cd my-project/        # if .envrc exists, environment auto-loads
                      # (nix develop, env vars, etc.)
```

No action needed — it detects `.envrc` files automatically.

#### jq — JSON Processor

```bash
jq '.' file.json                # pretty-print JSON
jq '.name' package.json         # extract field
gh api /user | jq '.login'      # filter API output
curl -s url | jq '.data[]'      # process API responses
```

#### xh — Friendly HTTP Client

```bash
xh GET api.github.com           # GET request with colored output
xh POST api.example.com key=val # POST with auto-JSON body
xh GET url | jq '.items'        # pipe to jq
```

### System & Disk

#### btop — System Monitor

```bash
btop                  # CPU, GPU, RAM, processes, network, disk
```

AMD GPU-aware (rocm-smi integration on ryzen). Breeze-dark themed.

#### dust — Disk Usage

```bash
dust                  # visual bar chart of what's eating disk space
dust -n 20            # show top 20 entries
dust /nix/store       # check specific directory
```

#### duf — Filesystem Overview

```bash
duf                   # clean table of all mounted filesystems with usage bars
```

#### sysdiag — System Diagnostics

```bash
sysdiag               # comprehensive system info (custom script)
```

#### tokei — Code Statistics

```bash
tokei                 # lines of code by language in current project
tokei --sort code     # sort by code lines
```

#### hyperfine — Benchmarking

```bash
hyperfine 'command1' 'command2'  # compare two commands with stats
hyperfine --warmup 3 'nix eval ...'  # benchmark with warm-up runs
```

### Quick Reference

#### tealdeer — Command Cheatsheets

```bash
tldr tar              # 5 most common tar examples
tldr rsync            # common rsync patterns
tldr nix              # nix command examples
```

Auto-updates its database. Way faster than reading man pages for quick reference.

### Terminal Workspace

#### zellij — Multiplexer

```bash
zellij                          # start new session
zellij attach                   # reattach to existing session
zellij -l compact               # start with compact layout
```

| Key                   | Action                              |
| --------------------- | ----------------------------------- |
| **Ctrl+P** then arrow | Switch to pane mode, navigate panes |
| **Ctrl+T** then arrow | Switch to tab mode, navigate tabs   |
| **Ctrl+N**            | New pane                            |
| **Ctrl+P** then **d** | Pane mode → close pane              |
| **Ctrl+O** then **d** | Detach session (keeps running)      |
| **Alt+n**             | New pane (quick)                    |
| **Alt+←/→**           | Switch tabs                         |

Compact layout (no pane frames, minimal chrome). Breeze-dark themed. Mouse works. Scrollback opens in neovim.

The status bar at the bottom shows available keybindings for the current mode — you never have to memorize anything.

## Integration Map

### What feeds into what

```
ripgrep ──► fzf (Ctrl+T: file listing)
         ──► neovim telescope (Space fg: live grep)

fd ──► fzf (Alt+C: directory listing)
    ──► neovim telescope (Space ff: file finding)

bat ──► zsh (cat alias)
     ──► fzf (Ctrl+T: syntax preview in right pane)
     ──► man (MANPAGER: colored man pages)
     ──► delta (syntax theme for git diffs)

eza ──► zsh (ls alias, with icons + git status)
     ──► fzf (Alt+C: tree preview for directories)

delta ──► git (automatic pager for diff/log/blame)

zoxide ──► zsh (z command for smart cd)
        ──► yazi (directory learning/jumping)

yazi ──► zsh (y wrapper syncs cwd on exit)
      ──► neovim (Space fy: file picker)
      ──► zoxide (updates directory database)

lazygit ──► neovim (Space gl: opens in terminal tab)
         ──► delta (uses delta as diff pager)

jq ──► gh (pipe GitHub API output)
    ──► xh (pipe HTTP responses)
    ──► nix eval (process Nix JSON output)

theme ──► zsh (autosuggestion color)
       ──► starship (prompt palette)
       ──► fzf (all colors + preview background)
       ──► bat (base16 syntax theme)
       ──► neovim (100+ highlight groups)
       ──► lazygit (UI theme)
       ──► btop (breeze-dark theme)
       ──► yazi (file manager colors)
       ──► konsole (terminal colorscheme)
       ──► delta (diff line number colors)
       ──► zellij (workspace theme)
```

### What runs automatically (no action needed)

| Tool                    | What it does in the background             |
| ----------------------- | ------------------------------------------ |
| starship                | Shows prompt with git/nix info             |
| fzf-tab                 | Enhances every Tab completion              |
| zsh autosuggestions     | Ghost text from history                    |
| zsh syntax highlighting | Colors valid/invalid commands as you type  |
| bat                     | Powers cat alias, man colors, fzf previews |
| eza                     | Powers ls alias with icons                 |
| zoxide                  | Learns directories as you cd               |
| delta                   | Colors every git diff/log/blame            |
| direnv                  | Auto-loads project environments            |
| gitsigns (neovim)       | Shows git changes in editor gutter         |
| format-on-save (neovim) | Formats on every :w                        |
| arkenfox                | Downloads Firefox hardening rules daily    |
| theme                   | Propagates breeze-dark to 11 tools         |

### What you invoke when needed

| Tool             | When to use it          |
| ---------------- | ----------------------- |
| `nvim`           | Edit code               |
| `lazygit`        | Visual git operations   |
| `y`              | Browse files            |
| `btop`           | Check system resources  |
| `zellij`         | Multi-pane workspace    |
| `tldr X`         | Quick command reference |
| `dust`           | Find what's eating disk |
| `duf`            | Check filesystem usage  |
| `rg "X"`         | Search code             |
| `sd 'old' 'new'` | Find-and-replace        |
| `glow X.md`      | Read markdown           |
| `xh GET url`     | HTTP requests           |
| `jq '.' file`    | Process JSON            |
| `tokei`          | Code statistics         |
| `hyperfine`      | Benchmark commands      |
| `sysdiag`        | System diagnostics      |
