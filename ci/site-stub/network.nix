{
  subnet = "10.0.0.0/24";
  domain = "ci.local";
  gateway = "10.0.0.1";
  dns = "10.0.0.1";

  wifi.ssid = "ci-stub-ssid";

  hosts = {
    ryzen-9950x3d = {
      ip = "10.0.0.10";
    };
    fcse01 = {
      ip = "10.0.0.11";
    };
  };

  builders = {
    aux = {
      hostName = "10.0.0.11";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub-key-not-real";
    };
    pixel-9-pro = {
      hostName = "127.0.0.1";
      port = 2222;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub-key-not-real";
    };
  };
}
