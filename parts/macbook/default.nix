{ inputs, ... }:
{
  flake.nixosModules.macbook =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.macbook;
      inherit (config.boot.kernelPackages) kernel;

      # LLVM flags for Clang-based kernels (CachyOS)
      extraMakeFlags = if (kernel.stdenv.cc.isClang or false) then [ "LLVM=1" ] else [ ];
      extraBuildInputs =
        if (kernel.stdenv.cc.isClang or false) then
          [
            pkgs.llvmPackages.clang-unwrapped
            pkgs.llvmPackages.bintools-unwrapped
            pkgs.llvmPackages.lld
          ]
        else
          [
            pkgs.gcc-unwrapped
            pkgs.binutils-unwrapped
          ];

      # Select applesmc patch based on kernel version — the driver was rewritten in 6.19
      # (static globals → per-device struct), so the patch differs significantly.
      applesmcPatch =
        if lib.versionAtLeast kernel.version "6.19" then
          ./applesmc-6.19-fixes.patch
        else
          ./applesmc-comprehensive-fixes.patch;

      # Patched applesmc — fixes race conditions in keyboard backlight,
      # null pointer dereference in cache access, workqueue flush on cleanup
      applesmc-patched = pkgs.stdenv.mkDerivation {
        pname = "applesmc-patched";
        version = "${kernel.version}-patched";
        inherit (kernel) src;
        nativeBuildInputs = kernel.moduleBuildDependencies ++ extraBuildInputs;
        patches = [ applesmcPatch ];
        buildPhase = ''
          make -j$NIX_BUILD_CORES -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
            M=$PWD/drivers/hwmon \
            ${lib.concatStringsSep " " extraMakeFlags} \
            KBUILD_MODPOST_WARN=1 \
            modules
        '';
        installPhase = ''
          mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
          cp drivers/hwmon/applesmc.ko $out/lib/modules/${kernel.modDirVersion}/extra/
        '';
      };

      # Patched at24 — suppress regulator warning when no VCC regulator exists
      at24-patched = pkgs.stdenv.mkDerivation {
        pname = "at24-patched";
        version = "${kernel.version}-patched";
        inherit (kernel) src;
        nativeBuildInputs = kernel.moduleBuildDependencies ++ extraBuildInputs;
        patches = [ ./at24-suppress-regulator-warning.patch ];
        buildPhase = ''
          make -j$NIX_BUILD_CORES -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
            M=$PWD/drivers/misc/eeprom \
            ${lib.concatStringsSep " " extraMakeFlags} \
            KBUILD_MODPOST_WARN=1 \
            modules
        '';
        installPhase = ''
          mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
          cp drivers/misc/eeprom/at24.ko $out/lib/modules/${kernel.modDirVersion}/extra/
        '';
      };
    in
    {
      _class = "nixos";
      options.myModules.macbook = {
        patches.enable = lib.mkEnableOption "MacBook kernel patches (AppleSMC fixes, AT24 warning suppression)";

        fan = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "mbpfan daemon for MacBook fan control";
          };
          lowTemp = lib.mkOption {
            type = lib.types.int;
            default = 45;
            description = "Temperature to start ramping fan (Celsius)";
          };
          highTemp = lib.mkOption {
            type = lib.types.int;
            default = 65;
            description = "Temperature for high fan speed (Celsius)";
          };
          maxTemp = lib.mkOption {
            type = lib.types.int;
            default = 80;
            description = "Maximum temperature before full fan (Celsius)";
          };
          pollingInterval = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Fan polling interval in seconds";
          };
        };

        touchpad = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "MacBook touchpad with natural scrolling and tap-to-click";
          };
          naturalScrolling = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Natural (reverse) scrolling direction";
          };
          tapping = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Tap-to-click";
          };
        };

        keyboard = {
          fnMode = lib.mkOption {
            type = lib.types.enum [
              0
              1
              2
            ];
            default = 2;
            description = "Apple keyboard fn key behavior (0=disabled, 1=press fn for media, 2=press fn for F-keys)";
          };
          swapOptCmd = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Swap Option and Command keys (makes Cmd act as Alt)";
          };
        };
      };

      config = lib.mkMerge [
        # Kernel patches
        (lib.mkIf cfg.patches.enable {
          boot.extraModulePackages = [
            applesmc-patched
            at24-patched
          ];
          boot.kernelModules = [
            "applesmc"
            "at24"
          ];
        })

        # Fan control
        (lib.mkIf cfg.fan.enable {
          services.mbpfan = {
            enable = true;
            verbose = false;
            settings.general = {
              low_temp = cfg.fan.lowTemp;
              high_temp = cfg.fan.highTemp;
              max_temp = cfg.fan.maxTemp;
              polling_interval = cfg.fan.pollingInterval;
            };
          };
        })

        # Touchpad
        (lib.mkIf cfg.touchpad.enable {
          services.libinput = {
            enable = true;
            touchpad = {
              inherit (cfg.touchpad) naturalScrolling;
              inherit (cfg.touchpad) tapping;
              clickMethod = "clickfinger";
              disableWhileTyping = true;
            };
          };
        })

        # Apple keyboard
        {
          boot.extraModprobeConfig = lib.mkAfter ''
            options hid_apple fnmode=${toString cfg.keyboard.fnMode}
            ${lib.optionalString cfg.keyboard.swapOptCmd "options hid_apple swap_opt_cmd=1"}
          '';
          boot.kernelModules = [ "hid_apple" ];
        }
      ];
    };
}
