# keyboard — MacBook keyboard remap (Cmd→Ctrl via xkb).
#
# Remaps the ⌘ Cmd key to Ctrl via xkb. Assumes the NixOS side sets
# `myModules.hardware.hidApple.swapOptCmd = false` so that physical Cmd
# emits KEY_LEFTMETA at the kernel level — this xkb option then swaps
# Left Meta with Left Ctrl, producing Cmd → Ctrl end-to-end.
#
# This module only adds the ctrl:swap_lwin_lctl option. Host files remain
# free to add their own generic preferences (e.g. caps:super) to
# programs.plasma.input.keyboard.options — the list is merged.
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
