{
  syncthing.deviceId = "CISTUBAUX-0000000-0000000-0000000-0000000-0000000-AAAA";
  ssh = {
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub";
    initrdHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub";
    trustedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
    remoteBuilder.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
  };
  hardware.macAddress = "00:00:00:00:00:00";
}
