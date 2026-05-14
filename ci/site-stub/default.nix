# site-stub — CI-only placeholder for the private site input.
# Mirrors the real site's attribute structure with dummy values so
# nix flake check can evaluate all hosts without the local-only
# site git repo. Values here are never deployed — only used for
# type-checking and evaluation in CI.
{
  hosts = {
    ryzen-9950x3d = import ./hosts/ryzen-9950x3d.nix;
    macbook-pro-9-2 = import ./hosts/macbook-pro-9-2.nix;
    pixel-9-pro = import ./hosts/pixel-9-pro.nix;
    fcse01 = import ./hosts/fcse01.nix;
  };
  network = import ./network.nix;
}
