# keyboard — MacBook keyboard remap (Cmd→Ctrl via xkb).
#
# Remaps the ⌘ Cmd key to Ctrl via xkb. Assumes the NixOS side sets
# `myModules.hardware.hidApple.swapOptCmd = false` so that physical Cmd
# emits KEY_LEFTMETA at the kernel level — this xkb option then swaps
# Left Meta with Left Ctrl, producing Cmd → Ctrl end-to-end.
#
# This module only adds ctrl:swap_lwin_lctl. The caps:super baseline is supplied
# by home/modules/plasma/input.nix for every Plasma host -- do NOT re-add either
# option per-host. plasma-manager merges this list across modules, so a re-added
# option is written twice into kxkbrc and KWin rejects the duplicate.
{ config, lib, ... }:
let
  cfg = config.myModules.home.macbook.keyboard;
in
{
  options.myModules.home.macbook.keyboard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.myModules.home.macbook.enable;
      description = "Enable Apple-keyboard Cmd (⌘) → Ctrl remap via xkb.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.input.keyboard.options = [ "ctrl:swap_lwin_lctl" ];
  };
}
