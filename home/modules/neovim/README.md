# Neovim IDE Layer

Declarative 3-file Neovim IDE, managed entirely through Nix. No manual plugin installation, no Mason, no lazy.nvim — everything is pinned by the flake lockfile.

## Quick Start

```bash
# Terminal (full IDE, same plugins/LSPs/theme)
nvim

# GUI (GPU-accelerated Neovide frontend)
# Click "Neovim" in KDE app drawer, or:
neovide

# Open a project
cd ~/Documents/nix && nvim .
cd ~/Documents/<work-monorepo>/<sub-project>/App && nvim .
```

## Architecture

```
home/modules/neovim/
├── default.nix    Core editor: treesitter, telescope, which-key, gitsigns,
│                  lualine, cmp engine, Neovide GUI + KDE desktop entry
├── ui.nix         Visual IDE layer: neo-tree sidebar, bufferline tabs,
│                  noice (floating cmdline/LSP/messages), trouble
│                  (problems panel), nvim-web-devicons
└── lsp.nix        Language tooling: per-language LSP sub-toggles,
                   LuaSnip + friendly-snippets, direnv-vim,
                   nvim-ts-autotag, conform.nvim format-on-save
```

## Enable

```nix
# In your host config (e.g. home/hosts/ryzen-9950x3d/default.nix)
myModules.home.neovim.enable = true;
myModules.home.neovim.ui.enable = true;
myModules.home.neovim.lsp.enable = true;
myModules.home.neovim.lsp.c = true;
myModules.home.neovim.lsp.typescript = true;
# ... see Options below
```

## Options

### `myModules.home.neovim.enable` (bool)

Master toggle. Sets `$EDITOR=nvim` by default.

### `myModules.home.neovim.ui.enable` (bool, default = neovim.enable)

Visual IDE layer: neo-tree sidebar, bufferline tabs, trouble problems panel, noice floating cmdline/LSP, file icons.

### `myModules.home.neovim.lsp.enable` (bool, default = neovim.enable)

Core LSP infrastructure: direnv auto-loading, LuaSnip + friendly-snippets, nvim-ts-autotag, conform.nvim format-on-save.

### `myModules.home.neovim.lsp.<lang>` (bool)

Per-language sub-toggles. Each one adds its LSP binary, vim.lsp.config, conform formatter, and treesitter grammar.

| Toggle           | Default | LSPs                                   | Formatters   | Grammars                           |
| ---------------- | ------- | -------------------------------------- | ------------ | ---------------------------------- |
| `lsp.nix`        | `true`  | nixd                                   | nixfmt       | nix                                |
| `lsp.bash`       | `true`  | bash-language-server                   | shfmt        | bash                               |
| `lsp.c`          | `false` | clangd                                 | clang-format | c, cpp                             |
| `lsp.typescript` | `false` | typescript-language-server, eslint-lsp | prettierd    | typescript, tsx, javascript, jsdoc |
| `lsp.dotnet`     | `false` | omnisharp                              | csharpier    | c_sharp                            |
| `lsp.powershell` | `false` | powershell-editor-services             | (bundled)    | powershell                         |
| `lsp.spell`      | `false` | cspell CLI (`:CspellCheck`)            | —            | —                                  |

### `myModules.home.neovim.settings` (attrs)

Overrides merged over module defaults via `lib.recursiveUpdate`:

```nix
myModules.home.neovim.settings = {
  viAlias = true;
  withPython3 = true;
};
```

## Per-Host Enablement

**ryzen-9950x3d** — all 7 language sub-toggles enabled (full IDE for all projects).

**macbook-pro-9-2** — nix + bash + c + spell only. No typescript/dotnet/powershell (keeps closure lean, MacBook doesn't do React Native or .NET work).

## CLI Tool Integration

These HM modules are wired directly into neovim:

| Tool             | How it connects                                                            | Keybind                 |
| ---------------- | -------------------------------------------------------------------------- | ----------------------- |
| **ripgrep**      | Powers live grep across project                                            | `<space>fg`             |
| **fd**           | Powers find files (respects .gitignore)                                    | `<space>ff`             |
| **yazi**         | Opens file manager in a neovim tab                                         | `<space>fy`             |
| **lazygit**      | Opens full git TUI in a neovim tab                                         | `<space>gl`             |
| **direnv**       | `direnv-vim` auto-loads `.envrc` — devshell tools become available to LSPs | automatic               |
| **bat**          | Telescope uses it for file previews                                        | automatic               |
| **delta**        | Used by lazygit for diff rendering                                         | inside lazygit          |
| **fzf**          | `telescope-fzf-native` gives fuzzy matching in all pickers                 | automatic               |
| **nixfmt**       | Format-on-save for `.nix` files                                            | automatic / `<space>lf` |
| **shfmt**        | Format-on-save for `.sh`/`.bash` files                                     | automatic               |
| **stylua**       | Format-on-save for `.lua` files                                            | automatic               |
| **prettierd**    | Format-on-save for TS/JS/JSON/MD/CSS/HTML                                  | automatic               |
| **clang-format** | Format-on-save for C/C++                                                   | automatic               |
| **csharpier**    | Format-on-save for C#                                                      | automatic               |
| **cspell**       | Spell check (en/de/es) via `:CspellCheck` command                          | `:CspellCheck`          |

## Working in ~/Documents/nix

```bash
cd ~/Documents/nix
nvim flake.nix
```

- **direnv** loads the flake's devshell automatically
- **nixd** starts with flake-aware completion — knows your `myModules.*` options, can autocomplete them, shows descriptions and types
- **treesitter** highlights Nix syntax with Breeze Dark theme
- **nixfmt** format-on-save fires on every `:w`
- `<space>ff` finds files (respects `.gitignore`, skips `repos/`, `.direnv/`)
- `<space>fg` greps across all nix files with ripgrep
- `<space>fd` shows diagnostics from nixd (type errors, undefined variables)
- `<space>xx` opens Trouble panel showing all nixd warnings project-wide
- `<space>e` opens neo-tree sidebar showing the flake directory structure

## Working in ~/Documents/<work-monorepo>

Different LSPs activate based on which subfolder and file type:

### C/C++ (embedded firmware, ESP32)

```bash
cd ~/Documents/<work-monorepo>/<sub-project>/<hw-variant>
nvim src/main.cpp
```

- **clangd** attaches (background indexing, clang-tidy, header suggestions)
- **clang-format** format-on-save
- Needs `compile_commands.json` — generate with `pio run --target compiledb` or `bear -- make`

### TypeScript/React Native (Mobile app)

```bash
cd ~/Documents/<work-monorepo>/<sub-project>/App
nvim App.tsx
```

- **typescript-language-server** attaches (imports, type checking, go-to-definition)
- **eslint-lsp** attaches (linting rules from `.eslintrc` / `eslint.config.js`)
- **prettierd** format-on-save
- **nvim-ts-autotag** auto-closes and auto-renames JSX/TSX tags
- **LuaSnip + friendly-snippets** — type `rfc` + Tab for React functional component, `useState` + Tab for hook, etc.

### C# / .NET (decryptor)

```bash
cd ~/Documents/<work-monorepo>/<sub-project>/<decryptor-dir>
nvim Program.cs
```

- **OmniSharp** attaches (C# completions, go-to-definition, references)
- **csharpier** format-on-save
- Root markers: `*.sln`, `*.csproj`, `global.json`

### PowerShell (build tooling)

```bash
cd ~/Documents/<work-monorepo>/<tooling-dir>
nvim dev.ps1
```

- **powershell-editor-services** attaches (completions, PSScriptAnalyzer linting, bundled formatter)

## Keybindings

Leader key is **Space**. Press Space and wait 100ms to see the which-key popup.

### Finding Things (`<space>f`)

| Key         | Action              |
| ----------- | ------------------- |
| `<space>ff` | Find files (fd)     |
| `<space>fg` | Live grep (ripgrep) |
| `<space>fb` | Switch buffer       |
| `<space>fh` | Help tags           |
| `<space>fd` | All diagnostics     |
| `<space>fr` | Recent files        |
| `<space>fy` | Yazi file manager   |

### IDE Panels

| Key         | Action                                   |
| ----------- | ---------------------------------------- |
| `<space>e`  | Toggle neo-tree sidebar (file explorer)  |
| `<space>xx` | Toggle Trouble — all project diagnostics |
| `<space>xd` | Buffer diagnostics only                  |
| `<space>xr` | LSP references for symbol under cursor   |
| `<space>xq` | Quickfix list                            |
| `<space>xl` | Location list                            |

### Code Navigation (no leader needed)

| Key         | Action                                |
| ----------- | ------------------------------------- |
| `gd`        | Go to definition                      |
| `gD`        | Go to declaration                     |
| `gr`        | Show all references                   |
| `K`         | Hover docs (type info, documentation) |
| `<C-k>`     | Signature help (in insert mode)       |
| `]d` / `[d` | Next / prev diagnostic                |
| `]c` / `[c` | Next / prev git hunk                  |

### LSP Actions (`<space>l`)

| Key         | Action                       |
| ----------- | ---------------------------- |
| `<space>ld` | Go to definition             |
| `<space>lr` | References                   |
| `<space>ln` | Rename symbol (project-wide) |
| `<space>la` | Code action (quick fix menu) |
| `<space>lh` | Hover docs                   |
| `<space>lf` | Format buffer                |
| `<space>li` | Go to implementation         |

### Git (`<space>g`)

| Key         | Action                        |
| ----------- | ----------------------------- |
| `<space>gs` | Stage hunk                    |
| `<space>gr` | Reset hunk                    |
| `<space>gb` | Blame line (full commit info) |
| `<space>gp` | Preview hunk diff             |
| `<space>gl` | Open lazygit                  |

### Buffers (`<space>b`)

| Key         | Action          |
| ----------- | --------------- |
| `<space>bn` | Next buffer     |
| `<space>bp` | Previous buffer |
| `<space>bd` | Delete buffer   |

### Windows (`<space>w`)

| Key               | Action              |
| ----------------- | ------------------- |
| `<space>ws`       | Horizontal split    |
| `<space>wv`       | Vertical split      |
| `<space>wc`       | Close window        |
| `<space>wh/j/k/l` | Move between splits |

### Completion

| Key               | Action                      |
| ----------------- | --------------------------- |
| `<C-Space>`       | Trigger completion          |
| `<C-n>` / `<C-p>` | Next / prev completion item |
| `<CR>`            | Confirm completion          |
| `<C-d>` / `<C-u>` | Scroll completion docs      |
| `<space>?`        | Cheat sheet (all keybinds)  |

## Verifying LSPs

In any file, run `:LspInfo` — shows which servers are attached and their status.

If a server isn't attached:

1. Is the sub-toggle enabled? Check `home/hosts/<hostname>/default.nix`
2. Is the file type correct? Run `:set ft?` to check
3. Does the project have root markers? (e.g., `tsconfig.json` for TS, `compile_commands.json` for C++)
4. Is direnv loaded? Check `:!echo $PATH | tr : '\n' | head` for devshell paths

## Neovide vs Terminal

Both use the exact same config, plugins, LSPs, and theme. Neovide adds:

- GPU-accelerated rendering (WGPU)
- Railgun cursor effect
- Slight transparency (0.95)
- 8px padding around all edges
- `Ctrl+Shift+C` / `Ctrl+Shift+V` for GUI clipboard
- Refresh rate locked to 60Hz

The KDE app drawer entry (`xdg.desktopEntries.nvim`) is overridden to show "Neovim" (not the stock "Neovim wrapper") and launches Neovide instead of a headless TUI.

## Plugins (22 total)

### Core (8, in default.nix)

| Plugin               | Purpose                                                            |
| -------------------- | ------------------------------------------------------------------ |
| nvim-treesitter      | Syntax highlighting + indent (grammars assembled from sub-toggles) |
| plenary-nvim         | Lua utility library (required by telescope + neo-tree)             |
| telescope-nvim       | Fuzzy finder for files, grep, buffers, diagnostics                 |
| telescope-fzf-native | FZF algorithm for telescope (faster sorting)                       |
| nvim-cmp             | Completion engine                                                  |
| which-key-nvim       | Keybind discovery popup (100ms delay)                              |
| lualine-nvim         | Statusline                                                         |
| gitsigns-nvim        | Git change indicators in sign column                               |

### UI Layer (6, in ui.nix)

| Plugin            | Purpose                                                           |
| ----------------- | ----------------------------------------------------------------- |
| nvim-web-devicons | File/filetype icons (used by neo-tree + bufferline)               |
| neo-tree-nvim     | Left sidebar file explorer with git status                        |
| bufferline-nvim   | VSCode-style tabs along the top with LSP diagnostic counts        |
| nui-nvim          | UI primitives (required by noice)                                 |
| noice-nvim        | Routes cmdline, LSP hover/signature, messages to floating windows |
| trouble-nvim      | Project-wide diagnostics panel (the "Problems" tab)               |

### LSP Layer (8, in lsp.nix)

| Plugin            | Purpose                                                   |
| ----------------- | --------------------------------------------------------- |
| nvim-lspconfig    | LSP client configuration utilities                        |
| cmp-nvim-lsp      | LSP completion source for nvim-cmp                        |
| luasnip           | Snippet engine                                            |
| friendly-snippets | Community snippet library (React/TS/C++/etc.)             |
| cmp_luasnip       | Wires LuaSnip into nvim-cmp                               |
| direnv-vim        | Auto-loads `.envrc` in direnv-managed directories         |
| nvim-ts-autotag   | Treesitter-driven auto-close/rename for JSX/TSX/HTML tags |
| conform-nvim      | Format on save (formatters assembled from sub-toggles)    |

## Colorscheme

When `myModules.home.theme.enable = true`, the module applies a full **Breeze Dark** colorscheme covering editor chrome, treesitter groups, completion menu, diagnostics, git signs, telescope, which-key, and lualine. When disabled, Neovim uses its built-in default.

## Editor Settings

- Relative line numbers with absolute current line
- System clipboard (`unnamedplus`)
- Persistent undo (`undofile`)
- Smart case search (case-insensitive unless uppercase typed)
- 2-space indentation, spaces not tabs
- 8-line scroll margin
- Splits open right/below
- No intro screen
- 250ms update time, 300ms timeout for keybind sequences
