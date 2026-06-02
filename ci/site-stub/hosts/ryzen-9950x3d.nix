{
  syncthing.deviceId = "CI-STUB-RYZEN-0000000-0000000-0000000-0000000-0000000";
  ssh = {
    trustedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
    remoteBuilder.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub" ];
  };
  hardware.goxlrSerial = "CI-STUB";
  # Schema-complete mirror of the real site vfio shape (dummy values) so
  # `nix flake check` can eval the ryzen vfio-stealth specialisations in CI.
  vfio = {
    smbios = {
      manufacturer = "CI-STUB";
      product = "CI-STUB";
      biosVendor = "CI-STUB";
      biosVersion = "0000";
      biosDate = "01/01/2026";
      biosRelease = "0.0";
      serial = "CI-STUB";
      baseBoardVersion = "CI-STUB";
      baseBoardSerial = "CI-STUB";
      memory = {
        manufacturer = "CI-STUB";
        speed = 6000;
      };
      cache = {
        l1 = 512;
        l2 = 8192;
        l3 = 98304;
      };
      oemStrings = [ "CI-STUB" ];
      onboardDevices = [
        {
          designation = "CI-STUB";
          kind = "ethernet";
          instance = 1;
        }
      ];
    };
    ram.partNumber = "CI-STUB";
    monitor = {
      model = "CI-STUB";
      serial = "CI-STUB";
    };
    edid = {
      manufacturer = "CIS";
      modelAbbrev = "CI-STUB ";
      productCode = "0x0000";
      dpi = 96;
      week = 1;
      year = 2026;
    };
    disk = {
      model = "CI-STUB";
      serial = "CI-STUB";
      opticalModel = "CI-STUB";
    };
    acpiOem = {
      id = "CISTUB";
      tableId = "CISTUB  ";
    };
    macPrefix = "00:00:00";
  };
}
