{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "dmidecode";
  description = "dmidecode SMBIOS/DMI decoder";
})
  args
