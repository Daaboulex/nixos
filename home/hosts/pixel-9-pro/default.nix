{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.stateVersion = "26.11";

  # Override overlay packages — shared overlay is x86_64-only
  programs.ripgrep.package = pkgs.ripgrep;

  # HM Module Toggles — exhaustive, alphabetical
  myModules.home = {
    # ── Enabled: lean CLI essentials for headless builder ──
    atuin.enable = true;
    atuin.sync = false;
    bat.enable = true;
    btop.enable = true;
    comma.enable = true;
    curl.enable = true;
    delta.enable = true;
    dig.enable = true;
    direnv.enable = true;
    duf.enable = true;
    dust.enable = true;
    eza.enable = true;
    fastfetch.enable = true;
    fd.enable = true;
    fzf.enable = true;
    git.enable = true;
    glow.enable = true;
    hermes.enable = true;
    jq.enable = true;
    lazygit.enable = true;
    lsof.enable = true;
    man-pages.enable = true;
    nano.enable = true;
    neovim.enable = true;
    neovim.ui.enable = true;
    neovim.lsp.enable = true;
    neovim.lsp.nix = true;
    neovim.lsp.bash = true;
    nil.enable = true;
    nix-output-monitor.enable = true;
    nix-tree.enable = true;
    nvd.enable = true;
    ripgrep.enable = true;
    sd.enable = true;
    sox.enable = true;
    starship.enable = true;
    tcpdump.enable = true;
    tealdeer.enable = true;
    tokei.enable = true;
    tree.enable = true;
    wget.enable = true;
    xh.enable = true;
    zoxide.enable = true;
    zsh.enable = true;

    # ── Disabled: GUI, audio, gaming, desktop, hardware-specific ──
  };
}
