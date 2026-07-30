{
  machineId = "00000000000000000000000000000000";
  syncthing.deviceId = "CI-STUB-MACBOOK-0000000-0000000-0000000-0000000-000000";
  ssh = {
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub";
    trustedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
    remoteBuilder.hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub";
  };
  hardware.kingstonDiskId = "ci-stub";
}
