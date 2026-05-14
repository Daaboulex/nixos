{
  syncthing.deviceId = "CI-STUB-PIXEL-00000000-0000000-0000000-0000000-000000";
  builder = {
    system = "aarch64-linux";
    sshUser = "droid";
    sshPort = 2222;
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [
      "nixos-test"
      "benchmark"
      "big-parallel"
    ];
  };
  ssh = {
    authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
    remoteBuilder.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
  };
}
