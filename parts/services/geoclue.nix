# geoclue — GeoClue2 location service for automatic timezone and night-light.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "services";
  name = "geoclue";
  description = "GeoClue2 location service";
  config = _: {
    services.geoclue2 = {
      enable = true;
      enableWifi = false;
      submitData = false;
    };
  };
}
