# ui — Neovim visual IDE polish (sidebar, bufferline, notifications, icons).
# Gated on myModules.home.neovim.ui.enable, which defaults to the parent
# myModules.home.neovim.enable.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.neovim.ui;
in
{
  options.myModules.home.neovim.ui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.myModules.home.neovim.enable;
      description = "Visual IDE layer (sidebar, bufferline, trouble, noice, icons).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      plugins = with pkgs.vimPlugins; [
        nvim-web-devicons
        neo-tree-nvim
        bufferline-nvim
        nui-nvim
        noice-nvim
        trouble-nvim
      ];

      initLua = ''
        -- ============================================================
        -- UI Layer — visual IDE polish
        -- ============================================================

        -- nvim-web-devicons: required by neo-tree + bufferline
        require('nvim-web-devicons').setup({ default = true })

        -- neo-tree: left sidebar file explorer
        require('neo-tree').setup({
          close_if_last_window = true,
          popup_border_style = 'rounded',
          enable_git_status = true,
          enable_diagnostics = true,
          default_component_configs = {
            indent = {
              with_markers = true,
              with_expanders = true,
            },
            git_status = {
              symbols = {
                added     = '+',
                modified  = '~',
                deleted   = '-',
                renamed   = '→',
                untracked = '?',
                ignored   = '·',
                unstaged  = 'U',
                staged    = 'S',
                conflict  = '!',
              },
            },
          },
          window = {
            width = 34,
            position = 'left',
          },
          filesystem = {
            follow_current_file = { enabled = true },
            use_libuv_file_watcher = true,
            filtered_items = {
              visible = false,
              hide_dotfiles = false,
              hide_gitignored = true,
            },
          },
          buffers = {
            follow_current_file = { enabled = true },
          },
          source_selector = {
            winbar = true,
            sources = {
              { source = 'filesystem', display_name = ' files' },
              { source = 'buffers',    display_name = ' bufs' },
              { source = 'git_status', display_name = ' git' },
            },
          },
        })

        -- bufferline: VSCode-style tabs along the top
        require('bufferline').setup({
          options = {
            mode = 'buffers',
            diagnostics = 'nvim_lsp',
            diagnostics_indicator = function(count, level)
              local icon = level:match('error') and '●' or '▲'
              return ' ' .. icon .. count
            end,
            offsets = {
              {
                filetype = 'neo-tree',
                text = 'File Explorer',
                highlight = 'Directory',
                separator = true,
              },
            },
            show_buffer_close_icons = true,
            show_close_icon = false,
            separator_style = 'thin',
          },
        })

        -- noice: routes cmdline, messages, LSP hover/signature to floating windows
        require('noice').setup({
          lsp = {
            override = {
              ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
              ['vim.lsp.util.stylize_markdown'] = true,
              ['cmp.entry.get_documentation'] = true,
            },
          },
          presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
            inc_rename = false,
            lsp_doc_border = true,
          },
          cmdline = {
            view = 'cmdline_popup',
          },
        })

        -- trouble: the Problems panel (project-wide diagnostics + references + quickfix)
        require('trouble').setup({
          auto_close = false,
          auto_preview = true,
          use_diagnostic_signs = true,
        })

        -- ============================================================
        -- UI Keybindings (registered with which-key if available)
        -- ============================================================
        local ok_wk, wk = pcall(require, 'which-key')
        if ok_wk then
          wk.add({
            -- Explorer
            { '<leader>e',  function() vim.cmd('Neotree toggle') end, desc = 'Explorer (neo-tree)' },

            -- Trouble (Problems panel)
            { '<leader>x',  group = 'Trouble' },
            { '<leader>xx', function() vim.cmd('Trouble diagnostics toggle') end,          desc = 'All diagnostics' },
            { '<leader>xd', function() vim.cmd('Trouble diagnostics toggle filter.buf=0') end, desc = 'Buffer diagnostics' },
            { '<leader>xr', function() vim.cmd('Trouble lsp_references toggle') end,      desc = 'LSP references' },
            { '<leader>xq', function() vim.cmd('Trouble qflist toggle') end,              desc = 'Quickfix list' },
            { '<leader>xl', function() vim.cmd('Trouble loclist toggle') end,             desc = 'Location list' },
          })
        end
      '';
    };
  };
}
