{ pkgs, lib, ... }:

{
  # ============================================================================
  # GDB — GNU Debugger configuration
  # ============================================================================
  # Enables useful debug output for crash reports (KDE, Mesa, etc.)
  # - auto-load safe-path: allow loading debug scripts from Nix store
  # - debuginfod: auto-download symbols from CachyOS debuginfod server
  home.packages = [ pkgs.gdb ];

  home.file.".gdbinit".text = ''
    # Allow auto-loading debug helper scripts from any path (Nix store)
    set auto-load safe-path /

    # Auto-download debug symbols from CachyOS debuginfod
    set debuginfod enabled on
    set debuginfod urls https://debuginfod.cachyos.org
  '';
}
