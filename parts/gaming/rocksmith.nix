# rocksmith — Rocksmith 2014 with WineASIO and RS_ASIO for low-latency guitar input.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.gaming.rocksmith;
    in
    {
      _class = "nixos";
      options.myModules.gaming.rocksmith = {
        enable = lib.mkEnableOption "Rocksmith 2014 with WineASIO and RS_ASIO";
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.myModules.gaming.steam.enable;
            message = "myModules.gaming.rocksmith: requires myModules.gaming.steam.enable = true. Enable Steam or disable Rocksmith.";
          }
          {
            assertion = config.myModules.hardware.pipewire.enable;
            message = "myModules.gaming.rocksmith: requires myModules.hardware.pipewire.enable = true. WineASIO needs PipeWire JACK.";
          }
        ];

        # Inject Rocksmith dependencies into Steam's FHS sandbox
        # extraLibraries: 32-bit libjack.so (WineASIO needs JACK in the sandbox)
        # extraPkgs: patch script, WineASIO DLLs, rs-autoconnect shim
        programs.steam.package = lib.mkDefault (
          pkgs.steam.override {
            extraLibraries = p: with p; [ pipewire.jack ];
            extraPkgs =
              p: with p; [
                patch-rocksmith
                wineasio
                wineasio-32
                rs-autoconnect
              ];
          }
        );

        # Real-time audio scheduling for WineASIO
        security.rtkit.enable = true;
        security.pam.loginLimits = [
          {
            domain = "@audio";
            type = "-";
            item = "memlock";
            value = "unlimited";
          }
          {
            domain = "@audio";
            type = "-";
            item = "rtprio";
            value = "99";
          }
        ];
      };
    };
in
{
  flake.modules.nixos.gaming-rocksmith = mod;

}
