# Yazi Module

Terminal file manager with git integration, fuzzy finding, and image previews — managed entirely through Nix.

## Enable

```nix
# In your host config (e.g. home/hosts/ryzen-9950x3d/default.nix)
myModules.home.yazi.enable = true;
```

## Architecture

```
home/modules/yazi/default.nix
├── Options        myModules.home.yazi.{enable, settings}
├── Plugins        3 Nix-managed yazi plugins (git, smart-enter, smart-filter)
├── Built-ins      zoxide jump + fzf search (configured via initLua)
├── Shell          y wrapper function for cwd-on-exit
└── Theme          Conditional Breeze Dark (active when myModules.home.theme.enable = true)
```

The module uses `lib.recursiveUpdate defaultSettings cfg.settings` so any attribute in `programs.yazi.settings` can be overridden per-host:

```nix
myModules.home.yazi.settings = {
  mgr.show_hidden = true;
  mgr.ratio = [ 1 2 5 ];
};
```

## Shell Wrapper

The `y` function wraps yazi with cwd-on-exit behavior — when you quit yazi (`q`), your shell changes to the directory you were browsing. This is injected via `programs.zsh.initContent` with `lib.mkAfter`.

**Why not `enableZshIntegration`?** Locked off due to [HM#5941](https://github.com/nix-community/home-manager/issues/5941). The manual wrapper is more reliable.

## Plugins (3)

| Plugin       | Purpose                                                                 |
| ------------ | ----------------------------------------------------------------------- |
| git          | Git status indicators in file list (modified, untracked, staged)        |
| smart-enter  | `l` enters directories or opens files in `$EDITOR`                      |
| smart-filter | `F` opens continuous filter — type to narrow the file list in real-time |

Plugins are installed from `pkgs.yaziPlugins` — no `.yazi` suffix needed (HM appends it automatically).

## Built-in Integrations

| Feature        | Key     | What it does                                                     |
| -------------- | ------- | ---------------------------------------------------------------- |
| Zoxide jump    | `Z`     | Frecency-ranked directory picker                                 |
| FZF search     | `z`     | Fuzzy file/directory search                                      |
| Syntax preview | (hover) | Right pane shows syntax-highlighted code via built-in syntect    |
| Image preview  | (hover) | Right pane renders images (Konsole KGP protocol, chafa fallback) |

## Keybindings

| Key       | Action                                                 |
| --------- | ------------------------------------------------------ |
| `l`       | Smart-enter: enter directory or open file in `$EDITOR` |
| `F`       | Smart-filter: continuous file list filtering           |
| `Z`       | Zoxide jump (built-in)                                 |
| `z`       | FZF search (built-in)                                  |
| `h`       | Parent directory                                       |
| `j` / `k` | Move down / up                                         |
| `q`       | Quit (cwd-on-exit via `y` wrapper)                     |

## Git Status

The git plugin registers two `prepend_fetchers` (for files `*` and directories `*/`) so status indicators appear automatically in any git repository. Configured in `initLua` with `require("git"):setup {}`.

## Colorscheme

When `myModules.home.theme.enable = true`, the module applies a full **Breeze Dark** theme using colors from the theme module. This covers:

- File manager chrome (CWD path, borders, markers)
- Status bar (mode indicators, permissions, progress)
- Tabs (active/inactive)
- Filetype coloring (images, archives, code files by extension)

When the theme module is disabled, yazi uses its built-in default theme.

## Default Settings

- Alphabetical sort, directories first
- Panel ratio: 1:3:4 (sidebar : list : preview)
- Hidden files off by default
- Logging disabled
