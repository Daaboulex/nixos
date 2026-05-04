# neovim — Neovim text editor with nixd LSP host and theme integration.
{
  config,
  lib,
  pkgs,
  myLib,
  inputs,
  osConfig ? { },
  ...
}:
let
  cfg = config.myModules.home.neovim;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
  # Derive hostname from NixOS config — no manual per-host override needed
  detectedHost = osConfig.networking.hostName;
in
{
  imports = [
    ./ui.nix
    ./lsp.nix
  ];

  options.myModules.home.neovim = {
    enable = lib.mkEnableOption "Neovim text editor";
    nixdHost = lib.mkOption {
      type = lib.types.str;
      default = detectedHost;
      description = "NixOS configuration name for nixd LSP option completions. Auto-detected from osConfig.networking.hostName.";
    };
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.neovide ];

    xdg.desktopEntries.nvim = {
      name = "Neovim";
      genericName = "Text Editor";
      exec = "neovide %F";
      terminal = false;
      icon = "nvim";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeType = [
        "text/plain"
        "text/x-lua"
        "text/x-c"
        "text/x-c++"
        "text/x-python"
        "text/x-shellscript"
        "text/x-csrc"
        "text/x-chdr"
        "text/x-csharp"
        "application/x-powershell"
        "text/x-nix"
        "application/json"
        "application/x-yaml"
        "application/toml"
      ];
      startupNotify = true;
    };

    programs.neovim = myLib.mergeSettings {
      defaults = {
        enable = true;
        defaultEditor = lib.mkDefault true;
        viAlias = lib.mkDefault false;
        vimAlias = lib.mkDefault false;
        withPython3 = lib.mkDefault false;
        withRuby = lib.mkDefault false;

        extraPackages = [
          pkgs.stylua
        ];

        plugins = [
          # New nvim-treesitter API (nixpkgs 26.05+) — `p` is an attrset of
          # grammars passed directly, replacing the legacy `with g; [ ... ]`
          # form (deprecated 26.04, removed 26.11).
          (pkgs.vimPlugins.nvim-treesitter.withPlugins (
            p:
            [
              p.nix
              p.bash
              p.lua
              p.python
              p.json
              p.yaml
              p.toml
              p.markdown
              p.markdown_inline
            ]
            ++ lib.optionals cfg.lsp.c [
              p.c
              p.cpp
            ]
            ++ lib.optionals cfg.lsp.typescript [
              p.typescript
              p.tsx
              p.javascript
              p.jsdoc
            ]
            ++ lib.optionals cfg.lsp.dotnet [ p.c_sharp ]
            ++ lib.optionals cfg.lsp.powershell [ p.powershell ]
          ))
          pkgs.vimPlugins.plenary-nvim
          pkgs.vimPlugins.telescope-nvim
          pkgs.vimPlugins.telescope-fzf-native-nvim
          pkgs.vimPlugins.nvim-cmp
          pkgs.vimPlugins.which-key-nvim
          pkgs.vimPlugins.lualine-nvim
          pkgs.vimPlugins.gitsigns-nvim
        ];
        # Total: 11 plugins (plenary required by telescope)

        initLua = ''
          -- ============================================================
          -- Neovide (GUI frontend) — only runs when launched via neovide
          -- ============================================================
          if vim.g.neovide then
            vim.g.neovide_cursor_vfx_mode = "railgun"
            vim.g.neovide_refresh_rate = 60
            vim.g.neovide_opacity = 0.95
            vim.g.neovide_padding_top = 8
            vim.g.neovide_padding_bottom = 8
            vim.g.neovide_padding_left = 8
            vim.g.neovide_padding_right = 8
            -- GUI clipboard shortcuts (standard X11/Wayland, not VSCode mimicry)
            vim.keymap.set({ 'n', 'v' }, '<C-S-c>', '"+y')
            vim.keymap.set({ 'n', 'v', 'i', 'c' }, '<C-S-v>', '<C-r>+')
          end

          -- ============================================================
          -- Editor Settings
          -- ============================================================
          vim.g.mapleader = ' '
          vim.g.maplocalleader = ' '

          vim.opt.number = true
          vim.opt.relativenumber = true
          vim.opt.cursorline = true
          vim.opt.signcolumn = 'yes'
          vim.opt.termguicolors = true
          vim.opt.showmode = false          -- lualine shows mode
          vim.opt.clipboard = 'unnamedplus' -- system clipboard
          vim.opt.breakindent = true
          vim.opt.undofile = true
          vim.opt.ignorecase = true
          vim.opt.smartcase = true
          vim.opt.updatetime = 250
          vim.opt.timeoutlen = 300
          vim.opt.splitright = true
          vim.opt.splitbelow = true
          vim.opt.scrolloff = 8
          vim.opt.tabstop = 2
          vim.opt.shiftwidth = 2
          vim.opt.expandtab = true
          vim.opt.shortmess:append('I')     -- suppress intro screen

          -- ============================================================
          -- Treesitter
          -- ============================================================
          -- Grammars installed by Nix (withPlugins); enable highlight + indent per filetype
          vim.api.nvim_create_autocmd('FileType', {
            callback = function(args)
              pcall(vim.treesitter.start, args.buf)
            end,
          })

          -- ============================================================
          -- Telescope
          -- ============================================================
          require('telescope').setup({
            defaults = {
              layout_strategy = 'horizontal',
              layout_config = { prompt_position = 'top' },
              sorting_strategy = 'ascending',
            },
            pickers = {
              find_files = {
                find_command = { 'fd', '--type', 'f', '--hidden', '--exclude', '.git' },
              },
            },
          })
          require('telescope').load_extension('fzf')

          -- ============================================================
          -- which-key (keybind discovery -- 100ms popup)
          -- ============================================================
          require('which-key').setup({
            delay = 100,
            preset = 'classic',
          })

          require('which-key').add({
            -- Group labels
            { '<leader>f', group = 'Find' },
            { '<leader>g', group = 'Git' },
            { '<leader>l', group = 'LSP' },
            { '<leader>b', group = 'Buffers' },
            { '<leader>w', group = 'Windows' },
            -- Cheat sheet
            { '<leader>?', function() require('which-key').show({ global = false }) end, desc = 'Cheat sheet' },

            -- Find (Telescope)
            { '<leader>ff', function() require('telescope.builtin').find_files() end, desc = 'Find files' },
            { '<leader>fg', function() require('telescope.builtin').live_grep() end, desc = 'Live grep' },
            { '<leader>fb', function() require('telescope.builtin').buffers() end, desc = 'Buffers' },
            { '<leader>fh', function() require('telescope.builtin').help_tags() end, desc = 'Help tags' },
            { '<leader>fd', function() require('telescope.builtin').diagnostics() end, desc = 'Diagnostics' },
            { '<leader>fr', function() require('telescope.builtin').oldfiles() end, desc = 'Recent files' },

            -- File manager (yazi)
            { '<leader>fy', function()
              vim.cmd('tabnew | terminal yazi ' .. vim.fn.expand('%:p:h'))
              vim.cmd('startinsert')
            end, desc = 'Yazi (file manager)' },

            -- Git (gitsigns + lazygit)
            { '<leader>gs', function() require('gitsigns').stage_hunk() end, desc = 'Stage hunk' },
            { '<leader>gr', function() require('gitsigns').reset_hunk() end, desc = 'Reset hunk' },
            { '<leader>gb', function() require('gitsigns').blame_line({ full = true }) end, desc = 'Blame line' },
            { '<leader>gp', function() require('gitsigns').preview_hunk() end, desc = 'Preview hunk' },
            { '<leader>gl', function()
              vim.cmd('tabnew | terminal lazygit')
              vim.cmd('startinsert')
            end, desc = 'Lazygit' },

            -- LSP
            { '<leader>ld', function() vim.lsp.buf.definition() end, desc = 'Go to definition' },
            { '<leader>lr', function() vim.lsp.buf.references() end, desc = 'References' },
            { '<leader>ln', function() vim.lsp.buf.rename() end, desc = 'Rename' },
            { '<leader>la', function() vim.lsp.buf.code_action() end, desc = 'Code action' },
            { '<leader>lh', function() vim.lsp.buf.hover() end, desc = 'Hover docs' },
            { '<leader>lf', function() require('conform').format({ timeout_ms = 500 }) end, desc = 'Format' },
            { '<leader>li', function() vim.lsp.buf.implementation() end, desc = 'Implementation' },

            -- Buffers
            { '<leader>bn', '<cmd>bnext<cr>', desc = 'Next buffer' },
            { '<leader>bp', '<cmd>bprevious<cr>', desc = 'Previous buffer' },
            { '<leader>bd', '<cmd>bdelete<cr>', desc = 'Delete buffer' },

            -- Windows
            { '<leader>ws', '<cmd>split<cr>', desc = 'Horizontal split' },
            { '<leader>wv', '<cmd>vsplit<cr>', desc = 'Vertical split' },
            { '<leader>wc', '<cmd>close<cr>', desc = 'Close window' },
            { '<leader>wh', '<C-w>h', desc = 'Move left' },
            { '<leader>wj', '<C-w>j', desc = 'Move down' },
            { '<leader>wk', '<C-w>k', desc = 'Move up' },
            { '<leader>wl', '<C-w>l', desc = 'Move right' },
          })

          -- Hunk navigation (outside which-key -- standard ]c/[c pattern)
          vim.keymap.set('n', ']c', function() require('gitsigns').next_hunk() end, { desc = 'Next hunk' })
          vim.keymap.set('n', '[c', function() require('gitsigns').prev_hunk() end, { desc = 'Prev hunk' })

          -- ============================================================
          -- gitsigns (git change indicators in gutter)
          -- ============================================================
          require('gitsigns').setup({
            signs = {
              add          = { text = '+' },
              change       = { text = '~' },
              delete       = { text = '-' },
              topdelete    = { text = '‾' },
              changedelete = { text = '~' },
            },
            current_line_blame = false,
          })

          -- ============================================================
          -- lualine (statusline)
          -- ============================================================
          require('lualine').setup({
            options = {
              theme = 'auto',
              section_separators = ''',
              component_separators = '|',
              globalstatus = true,
            },
            sections = {
              lualine_a = { 'mode' },
              lualine_b = { 'branch', 'diff', 'diagnostics' },
              lualine_c = { { 'filename', path = 1 } },
              lualine_x = { 'filetype' },
              lualine_y = { 'progress' },
              lualine_z = { 'location' },
            },
          })
        ''
        + lib.optionalString hasTheme ''
          -- ============================================================
          -- Breeze Dark Colorscheme (from myModules.home.theme)
          -- ============================================================
          vim.cmd('hi clear')
          local hl = vim.api.nvim_set_hl

          -- Editor backgrounds
          hl(0, 'Normal',       { bg = '${c.background}',   fg = '${c.foreground}' })
          hl(0, 'NormalFloat',  { bg = '${c.surface}',       fg = '${c.foreground}' })
          hl(0, 'FloatBorder',  { bg = '${c.surface}',       fg = '${c.foreground-dim}' })
          hl(0, 'CursorLine',   { bg = '${c.surface}' })
          hl(0, 'CursorLineNr', { fg = '${c.blue}',         bold = true })
          hl(0, 'LineNr',       { fg = '${c.foreground-dim}' })
          hl(0, 'Visual',       { bg = '${c.selection-alt}' })
          hl(0, 'Search',       { bg = '${c.selection-alt}', fg = '${c.foreground}' })
          hl(0, 'IncSearch',    { bg = '${c.blue}',          fg = '${c.background}' })
          hl(0, 'StatusLine',   { bg = '${c.surface}',       fg = '${c.foreground}' })
          hl(0, 'StatusLineNC', { bg = '${c.surface}',       fg = '${c.foreground-dim}' })
          hl(0, 'TabLine',      { bg = '${c.surface}',       fg = '${c.foreground-dim}' })
          hl(0, 'TabLineFill',  { bg = '${c.background}' })
          hl(0, 'TabLineSel',   { bg = '${c.blue}',          fg = '${c.foreground}' })
          hl(0, 'SignColumn',   { bg = '${c.background}' })
          hl(0, 'WinSeparator', { fg = '${c.surface-alt}' })
          hl(0, 'NonText',      { fg = '${c.surface-alt}' })

          -- Completion menu
          hl(0, 'Pmenu',        { bg = '${c.surface}',       fg = '${c.foreground}' })
          hl(0, 'PmenuSel',     { bg = '${c.selection-alt}', fg = '${c.foreground}' })
          hl(0, 'PmenuSbar',    { bg = '${c.surface-alt}' })
          hl(0, 'PmenuThumb',   { fg = '${c.foreground-dim}' })

          -- Treesitter semantic groups
          hl(0, '@keyword',            { fg = '${c.blue}',          bold = true })
          hl(0, '@keyword.function',   { fg = '${c.blue}',          bold = true })
          hl(0, '@keyword.return',     { fg = '${c.blue}',          bold = true })
          hl(0, '@keyword.import',     { fg = '${c.blue}',          bold = true })
          hl(0, '@function',           { fg = '${c.blue-alt}' })
          hl(0, '@function.call',      { fg = '${c.blue-alt}' })
          hl(0, '@function.builtin',   { fg = '${c.blue-alt}' })
          hl(0, '@string',             { fg = '${c.green}' })
          hl(0, '@string.escape',      { fg = '${c.orange}' })
          hl(0, '@comment',            { fg = '${c.foreground-dim}', italic = true })
          hl(0, '@variable',           { fg = '${c.foreground}' })
          hl(0, '@variable.builtin',   { fg = '${c.orange}' })
          hl(0, '@variable.parameter', { fg = '${c.foreground}',     italic = true })
          hl(0, '@number',             { fg = '${c.orange}' })
          hl(0, '@boolean',            { fg = '${c.orange}',         bold = true })
          hl(0, '@operator',           { fg = '${c.blue-alt}' })
          hl(0, '@type',               { fg = '${c.purple}' })
          hl(0, '@type.builtin',       { fg = '${c.purple}' })
          hl(0, '@constant',           { fg = '${c.orange}' })
          hl(0, '@constant.builtin',   { fg = '${c.orange}',         bold = true })
          hl(0, '@property',           { fg = '${c.foreground}' })
          hl(0, '@punctuation',        { fg = '${c.foreground}' })
          hl(0, '@punctuation.bracket', { fg = '${c.foreground-dim}' })
          hl(0, '@tag',                { fg = '${c.blue}' })
          hl(0, '@tag.attribute',      { fg = '${c.green}' })

          -- Diagnostics
          hl(0, 'DiagnosticError',       { fg = '${c.red}' })
          hl(0, 'DiagnosticWarn',        { fg = '${c.orange}' })
          hl(0, 'DiagnosticInfo',        { fg = '${c.blue}' })
          hl(0, 'DiagnosticHint',        { fg = '${c.foreground-dim}' })
          hl(0, 'DiagnosticSignError',   { fg = '${c.red}',    bg = '${c.background}' })
          hl(0, 'DiagnosticSignWarn',    { fg = '${c.orange}',  bg = '${c.background}' })
          hl(0, 'DiagnosticSignInfo',    { fg = '${c.blue}',    bg = '${c.background}' })
          hl(0, 'DiagnosticSignHint',    { fg = '${c.foreground-dim}', bg = '${c.background}' })
          hl(0, 'DiagnosticUnderlineError', { undercurl = true, sp = '${c.red}' })
          hl(0, 'DiagnosticUnderlineWarn',  { undercurl = true, sp = '${c.orange}' })

          -- Git signs
          hl(0, 'GitSignsAdd',    { fg = '${c.green}',  bg = '${c.background}' })
          hl(0, 'GitSignsChange', { fg = '${c.blue}',   bg = '${c.background}' })
          hl(0, 'GitSignsDelete', { fg = '${c.red}',    bg = '${c.background}' })

          -- Telescope
          hl(0, 'TelescopeBorder',       { fg = '${c.foreground-dim}', bg = '${c.background}' })
          hl(0, 'TelescopePromptBorder', { fg = '${c.blue}',           bg = '${c.background}' })
          hl(0, 'TelescopeTitle',        { fg = '${c.blue}',           bold = true })
          hl(0, 'TelescopeSelection',    { bg = '${c.surface}' })
          hl(0, 'TelescopeMatching',     { fg = '${c.green}',          bold = true })

          -- which-key
          hl(0, 'WhichKey',          { fg = '${c.blue}' })
          hl(0, 'WhichKeyGroup',     { fg = '${c.purple}' })
          hl(0, 'WhichKeyDesc',      { fg = '${c.foreground}' })
          hl(0, 'WhichKeyFloat',     { bg = '${c.surface}' })
          hl(0, 'WhichKeyBorder',    { fg = '${c.foreground-dim}', bg = '${c.surface}' })
          hl(0, 'WhichKeySeparator', { fg = '${c.foreground-dim}' })

          -- lualine will pick up Normal/StatusLine highlights automatically
        '';
      };
      overrides = cfg.settings;
    };
  };
}
