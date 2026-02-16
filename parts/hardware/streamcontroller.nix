{ inputs, ... }: {
  flake.nixosModules.hardware-streamcontroller = { config, lib, pkgs, ... }: {
    options.myModules.hardware.streamcontroller = {
      enable = lib.mkEnableOption "StreamController (Elgato Stream Deck)";
    };

    config = lib.mkIf config.myModules.hardware.streamcontroller.enable (let
      streamcontrollerPatched = pkgs.streamcontroller.overrideAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ pkgs.python3Packages.websockets ];
        postPatch = (old.postPatch or "") + ''
          find . -name "*.py" -exec sed -i 's/DeviceManager.USB_VID_ELGATO/0x0fd9/g' {} +
        '';
      });
      kdotoolFixed = pkgs.kdotool.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # Fix rust 1.80+ lifetime elision error in parser.rs (use turbofish syntax)
          if [ -f src/parser.rs ]; then
            sed -i "s/lexopt::Arg/lexopt::Arg::<'_>/g" src/parser.rs
          fi

          # Fix stricter type requirements in main.rs (Rust 2024 compat)
          if [ -f src/main.rs ]; then
            # Fix kwin_proxy.method_call globally
            sed -i 's/kwin_proxy.method_call(/kwin_proxy.method_call::<(), _, _, _>(/g' src/main.rs
            
            # Revert for (script_id,) assignment (line ~668) which needs inferred types, not unit
            sed -i 's/(script_id,) = kwin_proxy.method_call::<(), _, _, _>/(script_id,) = kwin_proxy.method_call/g' src/main.rs
            
            # Fix script_proxy.method_call globally
            sed -i 's/script_proxy.method_call(/script_proxy.method_call::<(), _, _, _>(/g' src/main.rs
            
            # Fix std::thread::spawn
            sed -i 's/std::thread::spawn(move/std::thread::spawn::<_, ()>(move/g' src/main.rs
          fi
        '';
      });
    in {
      environment.systemPackages = [ streamcontrollerPatched kdotoolFixed ];
      services.udev.packages = [ streamcontrollerPatched ];
    });
  };
}
