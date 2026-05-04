# lsp — Neovim language servers, formatters, snippets, direnv, treesitter.
# Per-language sub-toggles so hosts only pay RAM/closure cost for languages
# they use.
{
  config,
  lib,
  pkgs,
  inputs,
  osConfig ? { },
  ...
}:
let
  cfg = config.myModules.home.neovim.lsp;
  neovimCfg = config.myModules.home.neovim;
in
{
  options.myModules.home.neovim.lsp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = neovimCfg.enable;
      description = "LSP core (cmp, LuaSnip, friendly-snippets, direnv, ts-autotag).";
    };

    nix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "nixd LSP + nixfmt formatter.";
    };

    bash = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "bash-language-server + shfmt.";
    };

    c = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "clangd LSP + clang-format for C/C++/ESP32.";
    };

    typescript = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "typescript-language-server + eslint-lsp + prettierd + ts-autotag filetypes + friendly-snippets (React/JSX).";
    };

    dotnet = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "roslyn-ls LSP + csharpier formatter.";
    };

    powershell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "powershell-editor-services LSP (bundled formatter).";
    };

    spell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "cspell multi-language spell check CLI (en/de/es), exposed via :CspellCheck command.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      # Core LSP + snippet plugins (always present when lsp.enable is true)
      plugins = with pkgs.vimPlugins; [
        nvim-lspconfig
        cmp-nvim-lsp
        luasnip
        friendly-snippets
        cmp_luasnip
        direnv-vim
        nvim-ts-autotag
        conform-nvim
      ];

      # LSP binaries (gated on per-language sub-toggles below)
      extraPackages =
        lib.optionals cfg.nix [
          pkgs.nixd
          pkgs.nixfmt
        ]
        ++ lib.optionals cfg.bash [
          pkgs.bash-language-server
          pkgs.shfmt
        ]
        ++ lib.optionals cfg.c [ pkgs.clang-tools ]
        ++ lib.optionals cfg.typescript [
          pkgs.typescript-language-server
          pkgs.vscode-langservers-extracted
          pkgs.prettierd
        ]
        ++ lib.optionals cfg.dotnet [
          pkgs.omnisharp-roslyn
          pkgs.csharpier
        ]
        ++ lib.optionals cfg.powershell [ pkgs.powershell-editor-services ]
        ++ lib.optionals cfg.spell [ pkgs.cspell ];

      initLua = ''
        -- ============================================================
        -- LSP Core Infrastructure
        -- ============================================================
        local capabilities = require('cmp_nvim_lsp').default_capabilities()

        -- Load friendly-snippets (pulled in via LuaSnip's vscode snippet loader)
        require('luasnip.loaders.from_vscode').lazy_load()

        -- Wire LuaSnip as an nvim-cmp source (alongside the existing nvim_lsp source)
        local cmp = require('cmp')
        cmp.setup({
          snippet = {
            expand = function(args)
              require('luasnip').lsp_expand(args.body)
            end,
          },
          sources = cmp.config.sources({
            { name = 'nvim_lsp' },
            { name = 'luasnip' },
          }, {
            { name = 'buffer' },
          }),
          mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>']      = cmp.mapping.confirm({ select = true }),
            ['<C-n>']     = cmp.mapping.select_next_item(),
            ['<C-p>']     = cmp.mapping.select_prev_item(),
            ['<C-d>']     = cmp.mapping.scroll_docs(4),
            ['<C-u>']     = cmp.mapping.scroll_docs(-4),
          }),
        })

        -- nvim-ts-autotag: treesitter-driven auto-close/rename for HTML/JSX/TSX/Vue
        require('nvim-ts-autotag').setup()

        -- Diagnostic display: signs + virtual text + underline (no insert-mode updates)
        vim.diagnostic.config({
          virtual_text = true,
          signs = true,
          underline = true,
          update_in_insert = false,
          severity_sort = true,
        })

        -- Non-leader LSP keybindings (standard nvim idioms)
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Prev diagnostic' })
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition,   { desc = 'Go to definition' })
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration,  { desc = 'Go to declaration' })
        vim.keymap.set('n', 'gr', vim.lsp.buf.references,   { desc = 'LSP references' })
        vim.keymap.set('i', '<C-k>', vim.lsp.buf.signature_help, { desc = 'Signature help' })

        -- ============================================================
        -- conform.nvim — format on save, assembled from enabled languages
        -- ============================================================
        require('conform').setup({
          formatters_by_ft = {
            lua = { 'stylua' },
            ${lib.optionalString cfg.nix "nix = { 'nixfmt' },"}
            ${lib.optionalString cfg.bash "sh = { 'shfmt' }, bash = { 'shfmt' },"}
            ${lib.optionalString cfg.c "c = { 'clang-format' }, cpp = { 'clang-format' },"}
            ${lib.optionalString cfg.typescript ''
              typescript = { 'prettierd' },
              typescriptreact = { 'prettierd' },
              javascript = { 'prettierd' },
              javascriptreact = { 'prettierd' },
              json = { 'prettierd' },
              markdown = { 'prettierd' },
              css = { 'prettierd' },
              html = { 'prettierd' },
            ''}
            ${lib.optionalString cfg.dotnet "cs = { 'csharpier' },"}
          },
          format_on_save = {
            timeout_ms = 500,
            lsp_format = 'fallback',
          },
        })

        ${lib.optionalString cfg.nix ''
          -- ============================================================
          -- nixd: flake-aware option completion for THIS flake
          -- ============================================================
          vim.lsp.config('nixd', {
            capabilities = capabilities,
            settings = {
              nixd = {
                nixpkgs = {
                  expr = 'import "${inputs.nixpkgs}" { }',
                },
                options = {
                  nixos = {
                    expr = '(builtins.getFlake ("git+file://" + toString "${toString inputs.self}")).nixosConfigurations.${neovimCfg.nixdHost}.options',
                  },
                },
              },
            },
          })
          vim.lsp.enable('nixd')
        ''}

        ${lib.optionalString cfg.bash ''
          -- ============================================================
          -- bash-language-server
          -- ============================================================
          vim.lsp.config('bashls', { capabilities = capabilities })
          vim.lsp.enable('bashls')
        ''}

        ${lib.optionalString cfg.c ''
          -- ============================================================
          -- clangd (C / C++ / ESP32 firmware)
          -- ============================================================
          vim.lsp.config('clangd', {
            capabilities = capabilities,
            cmd = {
              'clangd',
              '--background-index',
              '--clang-tidy',
              '--completion-style=detailed',
              '--header-insertion=iwyu',
              '--suggest-missing-includes',
            },
            filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
            root_markers = { 'compile_commands.json', 'compile_flags.txt', '.clangd', '.git' },
          })
          vim.lsp.enable('clangd')
        ''}

        ${lib.optionalString cfg.typescript ''
          -- ============================================================
          -- typescript-language-server (JS / TS / JSX / TSX)
          -- ============================================================
          vim.lsp.config('ts_ls', {
            capabilities = capabilities,
            filetypes = {
              'javascript', 'javascriptreact', 'javascript.jsx',
              'typescript', 'typescriptreact', 'typescript.tsx',
            },
            root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
            init_options = {
              hostInfo = 'neovim',
              preferences = {
                importModuleSpecifierPreference = 'non-relative',
              },
            },
          })
          vim.lsp.enable('ts_ls')

          -- eslint-lsp (from vscode-langservers-extracted)
          vim.lsp.config('eslint', {
            capabilities = capabilities,
            filetypes = {
              'javascript', 'javascriptreact', 'javascript.jsx',
              'typescript', 'typescriptreact', 'typescript.tsx',
              'vue', 'svelte', 'astro',
            },
            root_markers = {
              '.eslintrc', '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.yaml',
              '.eslintrc.yml', '.eslintrc.json',
              'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
              'package.json', '.git',
            },
            settings = {
              workingDirectories = { mode = 'auto' },
              format = true,
            },
          })
          vim.lsp.enable('eslint')
        ''}

        ${lib.optionalString cfg.dotnet ''
          -- ============================================================
          -- OmniSharp (.NET / C#) — C# language server
          -- ============================================================
          vim.lsp.config('omnisharp', {
            capabilities = capabilities,
            cmd = { 'OmniSharp', '-lsp' },
            filetypes = { 'cs' },
            root_markers = { '*.sln', '*.csproj', 'global.json', '.git' },
          })
          vim.lsp.enable('omnisharp')
        ''}

        ${lib.optionalString cfg.powershell ''
          -- ============================================================
          -- powershell-editor-services (PowerShell)
          -- ============================================================
          vim.lsp.config('powershell_es', {
            capabilities = capabilities,
            bundle_path = '${pkgs.powershell-editor-services}',
            shell = 'pwsh',
            filetypes = { 'ps1', 'psm1', 'psd1' },
            root_markers = { '*.ps1', '*.psm1', '*.psd1', '.git' },
          })
          vim.lsp.enable('powershell_es')
        ''}

        ${lib.optionalString cfg.spell ''
          -- ============================================================
          -- cspell (multi-language spell check CLI — en/de/es)
          -- Exposed as :CspellCheck user command for the current buffer.
          -- ============================================================
          vim.api.nvim_create_user_command('CspellCheck', function()
            local file = vim.fn.expand('%:p')
            if file == "" then
              vim.notify('CspellCheck: no file in current buffer', vim.log.levels.WARN)
              return
            end
            vim.cmd('botright split | resize 10 | terminal cspell --locale en,de,es --show-context ' .. vim.fn.shellescape(file))
            vim.cmd('startinsert')
          end, { desc = 'Run cspell on the current file' })
        ''}
      '';
    };
  };
}
