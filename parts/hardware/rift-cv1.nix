# rift-cv1 -- Oculus Rift CV1 headset: Monado OpenXR runtime with the
# thaytan-OpenHMD constellation-tracking (6DoF) driver.
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
      cfg = config.myModules.hardware.riftCv1;
      # Packaged at the point of use (the services.scx.package pattern) -- no
      # global overlay: this module is the only consumer of these derivations.
      #
      # OpenHMD from the thaytan fork: the only live source of CV1 positional
      # tracking (upstream OpenHMD is unmaintained and gone from nixpkgs). The
      # fork's rift driver hard-requires hidapi + libusb + OpenCV at configure
      # time, so a missing dep fails the build instead of silently dropping
      # the driver.
      openhmd-rift = pkgs.stdenv.mkDerivation {
        pname = "openhmd-rift";
        version = "0-unstable-${inputs.openhmd-rift.shortRev}";
        src = inputs.openhmd-rift;
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.pkg-config
        ];
        buildInputs = [
          pkgs.hidapi
          pkgs.libusb1
          pkgs.opencv
        ];
        cmakeFlags = [
          # The fork predates CMake 4's minimum-version floor.
          "-DCMAKE_POLICY_VERSION_MINIMUM=3.10"
          "-DOPENHMD_EXAMPLE_SIMPLE=OFF"
          # Shared lib is REQUIRED: a static-only libopenhmd.a exports rift-s
          # symbols that collide with monado's own rift-s driver at link time;
          # the .so keeps them hidden (-fvisibility) so both drivers coexist.
          "-DBUILD_BOTH_STATIC_SHARED_LIBS=ON"
        ];
        meta = {
          description = "OpenHMD with Oculus Rift CV1 constellation (6DoF) tracking";
          homepage = "https://github.com/thaytan/OpenHMD";
          license = lib.licenses.boost;
        };
      };
      # Monado with the OpenHMD driver compiled in -- the CV1 OpenXR runtime.
      # The driver flag is forced ON so an undetected openhmd fails the build
      # instead of shipping a runtime that silently lacks the CV1 driver.
      monado-cv1 = pkgs.monado.overrideAttrs (old: {
        pname = "monado-cv1";
        buildInputs = old.buildInputs ++ [ openhmd-rift ];
        cmakeFlags = old.cmakeFlags ++ [ (lib.cmakeBool "XRT_BUILD_DRIVER_OHMD" true) ];
      });
    in
    {
      _class = "nixos";
      options.myModules.hardware.riftCv1 = {
        enable = lib.mkEnableOption "Oculus Rift CV1 (Monado + OpenHMD constellation tracking)";
      };
      config = lib.mkIf cfg.enable {
        # The nixpkgs module ships the xr-hardware udev rules and the
        # socket-activated user service; defaultRuntime publishes the OpenXR
        # runtime manifest system-wide for every consumer (xrizer, native
        # OpenXR apps).
        services.monado = {
          enable = true;
          package = monado-cv1;
          defaultRuntime = true;
        };
      };
    };
in
{
  flake.modules.nixos.hardware-rift-cv1 = mod;
}
