{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.myModules.gaming;
  
  # Get system architecture for eden package
  system = pkgs.stdenv.hostPlatform.system;
  
  # Heroic with optional extra packages for gaming support
  heroicWithExtras = pkgs.heroic.override {
    extraPkgs = pkgs: 
      [ pkgs.gamemode ]
      ++ lib.optionals cfg.gamescope.enable [ pkgs.gamescope ]
      ++ lib.optionals cfg.mangohud.enable [ pkgs.mangohud ];
  };
in {
  options.myModules.gaming = {
    enable = lib.mkEnableOption "Gaming optimizations and software";
    steam = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Steam"; };
      gamescope = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Gamescope session for Steam"; };
    };
    heroic = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Heroic Games Launcher (GOG, Epic, Amazon)"; };
    };
    gamescope = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Gamescope (HDR, frame limiting, upscaling)"; };
    };
    mangohud = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable MangoHud overlay (FPS, GPU/CPU stats)"; };
    };
    ryubing = {
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Ryubing (Nintendo Switch emulator, fork of Ryujinx)"; };
    };
    eden = {
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Eden (Nintendo Switch emulator, community fork)"; };
    };
    azahar = {
      enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Azahar (3DS emulator, Citra fork)"; };
    };
    packages = {
      performance = lib.mkOption { type = lib.types.bool; default = true; description = "Include performance packages"; };
      cachyos = lib.mkOption { type = lib.types.bool; default = true; description = "Use CachyOS optimized packages"; };
    };
  };
  
  config = lib.mkIf cfg.enable {
    programs.steam = lib.mkIf cfg.steam.enable {
      package = pkgs.steam.override { extraBwrapArgs = [ "--unsetenv" "TZ" ]; };
      enable = true;
      gamescopeSession.enable = cfg.steam.gamescope && cfg.gamescope.enable;
      # NOTE: Proton compat packages are managed via myModules.chaotic.gaming
    };

    # Enable Gamescope for Heroic and other launchers
    programs.gamescope.enable = cfg.gamescope.enable;
    
    # Enable Gamemode
    programs.gamemode.enable = true;

    # Steam hardware compatibility
    hardware.steam-hardware.enable = cfg.steam.enable;

    # Add necessary packages to the system
    environment.systemPackages = with pkgs; [
      steam-devices-udev-rules
      gamemode
    ] 
    ++ lib.optionals cfg.mangohud.enable [ mangohud ]
    ++ lib.optionals cfg.heroic.enable [ heroicWithExtras ]
    ++ lib.optionals cfg.ryubing.enable [ ryubing ]
    ++ lib.optionals cfg.eden.enable [ inputs.eden.packages.${system}.eden ]
    ++ lib.optionals cfg.azahar.enable [ azahar ];

    # Add user to the gamemode group
    users.users.${config.myModules.primaryUser}.extraGroups = [ "gamemode" ];
  };
}
# Gaming module
# Example: myModules.gaming = { enable = true; steam.enable = true; };
