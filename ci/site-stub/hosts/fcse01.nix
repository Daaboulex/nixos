{
  syncthing.deviceId = "CI-STUB-FCSE01-0000000-0000000-0000000-0000000-000000";
  ssh = {
    trustedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
    remoteBuilder.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
  };
  hardware.macAddress = "00:00:00:00:00:00";
}
