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
      description = "Roslyn LS (via roslyn.nvim) + csharpier formatter for C#/.NET.";
    };

    powershell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "powershell-editor-services LSP (bundled formatter).";
    };

    python = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "basedpyright LSP + ruff linter/formatter for Python.";
    };

    rust = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "rust-analyzer LSP for Rust (formats over LSP).";
    };

    go = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "gopls LSP for Go (formats over LSP).";
    };

    markdown = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "marksman LSP for Markdown (headings, links, references).";
    };

    lua = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "lua-language-server for Lua (neovim config, scripts).";
    };

    yaml = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "yaml-language-server for YAML (CI configs, platformio, docker-compose).";
    };

    json = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "JSON/HTML LSP from vscode-langservers-extracted (tsconfig, package.json).";
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
      plugins =
        (with pkgs.vimPlugins; [
          nvim-lspconfig
          cmp-nvim-lsp
          luasnip
          friendly-snippets
          cmp_luasnip
          cmp-buffer
          cmp-path
          direnv-vim
          nvim-ts-autotag
          conform-nvim
        ])
        ++ lib.optionals cfg.dotnet [ pkgs.vimPlugins.roslyn-nvim ];

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
        ]
        ++ lib.optionals (cfg.typescript || cfg.json || cfg.yaml || cfg.markdown) [
          pkgs.prettierd
        ]
        ++ lib.optionals cfg.dotnet [
          pkgs.roslyn-ls
          pkgs.csharpier
        ]
        ++ lib.optionals cfg.markdown [ pkgs.marksman ]
        ++ lib.optionals cfg.lua [ pkgs.lua-language-server ]
        ++ lib.optionals cfg.yaml [ pkgs.yaml-language-server ]
        ++ lib.optionals cfg.json [ pkgs.vscode-langservers-extracted ]
        ++ lib.optionals cfg.powershell [ pkgs.powershell-editor-services ]
        ++ lib.optionals cfg.python [
          pkgs.basedpyright
          pkgs.ruff
        ]
        ++ lib.optionals cfg.rust [ pkgs.rust-analyzer ]
        ++ lib.optionals cfg.go [ pkgs.gopls ]
        ++ lib.optionals cfg.spell [ pkgs.cspell ];

      initLua = ''
        -- ============================================================
        -- LSP Core Infrastructure
        -- ============================================================
        local capabilities = require('cmp_nvim_lsp').default_capabilities()

        -- Standards-first LSP wiring: every server inherits cmp capabilities and a
        -- .git root fallback from the '*' config, and nvim-lspconfig's maintained
        -- lsp/<server>.lua supplies cmd/filetypes/root detection (including the
        -- root_dir functions for ts_ls/rust_analyzer/gopls that a marker list can't
        -- express). Per-server blocks below carry ONLY non-standard settings.
        vim.lsp.config('*', {
          capabilities = capabilities,
          root_markers = { '.git' },
        })

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
            { name = 'path' },
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
              css = { 'prettierd' },
              html = { 'prettierd' },
            ''}
            ${lib.optionalString cfg.markdown "markdown = { 'prettierd' },"}
            ${lib.optionalString cfg.json "json = { 'prettierd' },"}
            ${lib.optionalString cfg.yaml "yaml = { 'prettierd' },"}
            ${lib.optionalString cfg.dotnet "cs = { 'csharpier' },"}
            ${lib.optionalString cfg.python "python = { 'ruff_format' },"}
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
            settings = {
              nixd = {
                nixpkgs = {
                  expr = 'import "${inputs.nixpkgs}" { }',
                },
                options = {
                  nixos = {
                    expr = '(builtins.getFlake "git+file://${neovimCfg.nixdFlakeDir}").nixosConfigurations.${neovimCfg.nixdHost}.options',
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
          vim.lsp.enable('bashls')
        ''}

        ${lib.optionalString cfg.c ''
          -- ============================================================
          -- clangd (C / C++ / ESP32 firmware)
          -- ============================================================
          vim.lsp.config('clangd', {
            cmd = {
              'clangd',
              '--background-index',
              '--clang-tidy',
              '--completion-style=detailed',
              '--header-insertion=iwyu',
              '--suggest-missing-includes',
            },
          })
          vim.lsp.enable('clangd')
        ''}

        ${lib.optionalString cfg.typescript ''
          -- ============================================================
          -- typescript-language-server (JS / TS / JSX / TSX)
          -- ============================================================
          vim.lsp.config('ts_ls', {
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
            settings = {
              workingDirectories = { mode = 'auto' },
              format = true,
            },
          })
          vim.lsp.enable('eslint')
        ''}

        ${lib.optionalString cfg.dotnet ''
          -- ============================================================
          -- Roslyn (.NET / C#) via roslyn.nvim -- the current C# server
          -- (Microsoft.CodeAnalysis.LanguageServer). The plugin registers and
          -- enables the 'roslyn' client itself; we only layer cmd/capabilities/
          -- settings via vim.lsp.config. Full analysis needs the .NET SDK on PATH,
          -- which lives in the project devShell (direnv) by design, not the host.
          -- Monorepo: broad_search finds .sln in child dirs; :Roslyn target picks one.
          -- ============================================================
          require('roslyn').setup({
            broad_search = true,
            lock_target = true,
          })
          vim.lsp.config('roslyn', {
            cmd = {
              '${lib.getExe pkgs.roslyn-ls}',
              '--logLevel', 'Information',
              '--extensionLogDirectory', vim.fs.joinpath(vim.fn.stdpath('log'), 'roslyn_ls'),
              '--stdio',
            },
            settings = {
              ["csharp|inlay_hints"] = {
                csharp_enable_inlay_hints_for_implicit_object_creation = true,
                csharp_enable_inlay_hints_for_implicit_variable_types = true,
              },
              ["csharp|code_lens"] = {
                dotnet_enable_references_code_lens = true,
              },
            },
          })
        ''}

        ${lib.optionalString cfg.powershell ''
          -- ============================================================
          -- powershell-editor-services (PowerShell)
          -- ============================================================
          vim.lsp.config('powershell_es', {
            bundle_path = '${pkgs.powershell-editor-services}',
            shell = 'pwsh',
          })
          vim.lsp.enable('powershell_es')
        ''}

        ${lib.optionalString cfg.markdown ''
          -- ============================================================
          -- marksman (Markdown — headings, links, references)
          -- ============================================================
          vim.lsp.enable('marksman')
        ''}

        ${lib.optionalString cfg.lua ''
          -- ============================================================
          -- lua-language-server (Lua — neovim config, scripts)
          -- ============================================================
          vim.lsp.config('lua_ls', {
            settings = {
              Lua = {
                runtime = { version = 'LuaJIT' },
                workspace = {
                  checkThirdParty = false,
                  library = { vim.env.VIMRUNTIME },
                },
                diagnostics = {
                  globals = { 'vim' },
                },
                telemetry = { enable = false },
              },
            },
          })
          vim.lsp.enable('lua_ls')
        ''}

        ${lib.optionalString cfg.yaml ''
          -- ============================================================
          -- yaml-language-server (YAML — CI, docker-compose, platformio)
          -- ============================================================
          vim.lsp.config('yamlls', {
            settings = {
              yaml = {
                validate = true,
                hover = true,
                completion = true,
                schemaStore = { enable = true, url = 'https://www.schemastore.org/api/json/catalog.json' },
              },
            },
          })
          vim.lsp.enable('yamlls')
        ''}

        ${lib.optionalString cfg.json ''
          -- ============================================================
          -- json-language-server (JSON — tsconfig, package.json, settings)
          -- ============================================================
          vim.lsp.config('jsonls', {
            settings = {
              json = {
                validate = { enable = true },
                schemaStore = { enable = true, url = 'https://www.schemastore.org/api/json/catalog.json' },
              },
            },
          })
          vim.lsp.enable('jsonls')
        ''}

        ${lib.optionalString cfg.python ''
          -- ============================================================
          -- basedpyright (types) + ruff (lint/format) for Python
          -- ============================================================
          vim.lsp.enable('basedpyright')
          vim.lsp.enable('ruff')
        ''}

        ${lib.optionalString cfg.rust ''
          -- ============================================================
          -- rust-analyzer (Rust)
          -- ============================================================
          vim.lsp.enable('rust_analyzer')
        ''}

        ${lib.optionalString cfg.go ''
          -- ============================================================
          -- gopls (Go)
          -- ============================================================
          vim.lsp.enable('gopls')
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
