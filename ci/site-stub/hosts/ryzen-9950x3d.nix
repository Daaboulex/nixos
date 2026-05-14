{
  syncthing.deviceId = "CI-STUB-RYZEN-0000000-0000000-0000000-0000000-0000000";
  ssh = {
    trustedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
    remoteBuilder.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
  };
  hardware.goxlrSerial = "CI-STUB";
  vfio = {
    ram.partNumber = "CI-STUB";
    monitor = {
      model = "CI-STUB";
      serial = "CI-STUB";
    };
    disk = {
      model = "CI-STUB";
      opticalModel = "CI-STUB";
    };
  };
}
