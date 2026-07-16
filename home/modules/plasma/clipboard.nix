# clipboard — Klipper: never persist clipboard history to disk (declarative pin).
# copy-on-select sends every selection to the system clipboard, so a persisted
# Klipper history would be an at-rest secret leak. This pins the safe state so it
# cannot drift back to the KDE default (KeepClipboardContents = true).
{ config, lib, ... }:
{
  # Gated like the plasma siblings: klipper only runs under Plasma, so a
  # non-Plasma host gets no klipperrc. This file is the ONLY klipperrc
  # writer (single source for the no-persist security pin).
  config = lib.mkIf config.myModules.home.plasma.enable {
    programs.plasma.configFile.klipperrc.General = {
      KeepClipboardContents = lib.mkDefault false; # do not save clipboard history across sessions
      PreventEmptyClipboard = lib.mkDefault true;
      MaxClipItems = lib.mkDefault 25;
      SyncClipboards = lib.mkDefault false; # Disable auto-copy on selection
    };
  };
}
