{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.stateVersion = "26.05";

  # Override overlay packages — shared overlay is x86_64-only
  programs.ripgrep.package = pkgs.ripgrep;

  # Git identity
  programs.git.userName = "Daaboulex";
  programs.git.userEmail = "39669593+Daaboulex@users.noreply.github.com";

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
    android.enable = false;
    antigravity.enable = false;
    anydesk.enable = false;
    archive.enable = false;
    arkenfox.enable = false;
    azahar.enable = false;
    bluez-tools.enable = false;
    brightnessctl.enable = false;
    c-cpp.enable = false;
    chafa.enable = false;
    cifs-utils.enable = false;
    claude-code.enable = false;
    cmake.enable = false;
    codex-cli.enable = false;
    coolercontrol.enable = false;
    corecycler.enable = false;
    crush.enable = false;
    csvlens.enable = false;
    devenv.enable = false;
    displays.enable = false;
    dmidecode.enable = false;
    durdraw.enable = false;
    easyeffects.enable = false;
    eden.enable = false;
    elisa.enable = false;
    ethtool.enable = false;
    ffmpeg.enable = false;
    flatpak.enable = false;
    gamescope.enable = false;
    gcc.enable = false;
    gdb.enable = false;
    gemini-cli.enable = false;
    gnumake.enable = false;
    goxlr.enable = false;
    gparted.enable = false;
    gpg.enable = false;
    gtk.enable = false;
    heroic.enable = false;
    htop.enable = false;
    hwinfo.enable = false;
    hyperfine.enable = false;
    ifuse.enable = false;
    inxi.enable = false;
    iodiag.enable = false;
    iommu.enable = false;
    iotop.enable = false;
    iw.enable = false;
    jaeger.enable = false;
    kate.enable = false;
    kdotool.enable = false;
    kiro.enable = false;
    konsole.enable = false;
    lact.enable = false;
    libimobiledevice.enable = false;
    llmfit.enable = false;
    lm-sensors.enable = false;
    lmstudio.enable = false;
    looking-glass.enable = false;
    lsfg-vk.enable = false;
    lshw.enable = false;
    macbook.enable = false;
    mangohud.enable = false;
    mangojuice.enable = false;
    memtest-vulkan.enable = false;
    minicom.enable = false;
    models.enable = false;
    moonlight.enable = false;
    mullvad.enable = false;
    nix-prefetch-git.enable = false;
    node.enable = false;
    ns-usbloader.enable = false;
    obsidian.enable = false;
    occt.enable = false;
    okular.enable = false;
    opencode.enable = false;
    openviking.enable = false;
    pastel.enable = false;
    pciutils.enable = false;
    pi.enable = false;
    piper.enable = false;
    pkg-config.enable = false;
    plasma.enable = false;
    powershell.enable = false;
    powertop.enable = false;
    prismlauncher.enable = false;
    protonplus.enable = false;
    pulsemixer.enable = false;
    python.enable = false;
    qpwgraph.enable = false;
    radeontop.enable = false;
    radv.enable = false;
    ryubing.enable = false;
    saleae.enable = false;
    samba.enable = false;
    sherlock.enable = false;
    smartmontools.enable = false;
    streamcontroller.enable = false;
    stress-ng.enable = false;
    syncthing.enable = false;
    sysbench.enable = false;
    sysdiag.enable = false;
    sysstat.enable = false;
    testdisk.enable = false;
    theme.enable = false;
    tidalcycles.enable = false;
    usbutils.enable = false;
    virt-manager.enable = false;
    vkbasalt.enable = false;
    vscode.enable = false;
    vulkan-tools.enable = false;
    wine.enable = false;
    xdg.enable = false;
    yazi.enable = false;
    yeetmouse.enable = false;
    zellij.enable = false;
  };
}
