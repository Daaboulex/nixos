rec {
  subnet = "10.0.0.0/24";
  domain = "ci.local";
  gateway = "10.0.0.1";
  dns = "10.0.0.1";

  wifi.ssid = "ci-stub-ssid";

  # Mirrors site.network.vpn shape (dummy values) for eval-site-stub-parity.
  vpn = {
    name = "CI Stub VPN";
    server = "vpn.ci.local";
    username = "ci-stub-user";
    verifyX509Name = "subject:C=CI, CN=ci-stub";
    routedSubnets = [ subnet ];
    dnsServer = dns;
    dnsDomains = [ domain ];
    hostRecords = [
      {
        name = "aux-host";
        ip = hosts.aux.ip;
      }
    ];
  };

  hosts = {
    ryzen-9950x3d = {
      ip = "10.0.0.10";
    };
    aux = {
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

  # Mirrors site.network.pins shape (dummy values; lists are opaque leaves).
  # hostNames must be non-empty: nixpkgs ssh.nix asserts hostNames != [] when
  # hosts are evaluated against this stub in CI.
  pins = {
    etcHosts = [
      {
        ip = "10.0.0.11";
        names = [ "ci-stub-host.ci.local" ];
      }
    ];
    sshKnownHosts = {
      aux-interactive = {
        hostNames = [ "ci-stub-host.ci.local" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub-key-not-real";
      };
      aux-initrd = {
        hostNames = [ "[ci-stub-host.ci.local]:2222" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIci-stub-key-not-real";
      };
    };
    sshClientSettings = [ ];
  };
}
