# minicom — serial terminal with user .minirc.dfl configuration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkDotfileModule {
  name = "minicom";
  description = "minicom serial terminal";
  file = ".minirc.dfl";
  exampleLines = "`pu port /dev/ttyUSB0`, `pu baudrate 115200`.";
})
  args
