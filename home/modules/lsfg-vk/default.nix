# lsfg-vk — Vulkan frame generation via Lossless Scaling shim.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.lsfg-vk;
in
{
  options.myModules.home.lsfg-vk = {
    enable = lib.mkEnableOption "lsfg-vk Vulkan frame generation (requires Lossless Scaling)";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.lsfg-vk ];
    home.sessionVariables = {
      DISABLE_LSFGVK = lib.mkDefault "1";
    };
  };
}
