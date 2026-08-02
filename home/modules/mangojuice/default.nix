# mangojuice — GUI for MangoHud configuration.
#
# Why the override: upstream patches the unforked vkBasalt library path into the
# binary for an installed-check, which pulls that layer into the closure beside
# vkbasalt-overlay. Both read ENABLE_VKBASALT, so both would apply at once, and
# MangoJuice's vkBasalt page writes a config the fork never reads. Emptying the
# input leaves that page reporting "not installed", which is true of the only
# vkBasalt it can actually drive.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "mangojuice";
  package = p: p.mangojuice.override { vkbasalt = p.emptyDirectory; };
  description = "MangoJuice GUI for MangoHud configuration";
})
  args
