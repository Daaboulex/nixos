{
  lib,
  stdenv,
  coreutils,
  writeShellScript,
  makeDesktopItem,
  kernel,
  glfw3,
  zenity,
  copyDesktopItems,
  autoPatchelfHook,
  makeWrapper,
  shortRev ? "dev",
  # Allow overriding these
  kernelModuleMakeFlags ? null,
}:

let
  actualKernelModuleMakeFlags = if kernelModuleMakeFlags != null then kernelModuleMakeFlags else kernel.makeFlags;
in
stdenv.mkDerivation rec {
  pname = "yeetmouse";
  version = shortRev;
  # Use the upstream source since we vendored the nix file but source is in flake input
  # We will override src in overlay
  src = ./../../..; # Placeholder, expect override or relative path if inside repo.
                   # BUT we are in /modules/yeetmouse. 
                   # Upstream used ./.. from nix/. 
                   # We should probably pass src as argument or handle it in overlay.

  setSourceRoot = "export sourceRoot=$(pwd)/source";
  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    makeWrapper
    autoPatchelfHook
    copyDesktopItems
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    glfw3
  ];

  makeFlags = actualKernelModuleMakeFlags ++ [
    "KBUILD_OUTPUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(sourceRoot)/driver"
  ];

  preBuild = ''
    cp $sourceRoot/driver/config.sample.h $sourceRoot/driver/config.h
  '';

  LD_LIBRARY_PATH = "/run/opengl-driver/lib:${lib.makeLibraryPath buildInputs}";

  postBuild = ''
    make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL"
  '';

  postInstall = let
    PATH = [ zenity ];
  in /*sh*/''
    install -Dm755 $sourceRoot/gui/YeetMouseGui $out/bin/yeetmouse
    wrapProgram $out/bin/yeetmouse \
      --prefix PATH : ${lib.makeBinPath PATH}
      
    # Install Raw Accel icon
    install -Dm644 ${./icons/rawaccel.png} $out/share/icons/hicolor/256x256/apps/rawaccel.png
  '';

  buildFlags = [ "modules" ];
  installFlags = [ "INSTALL_MOD_PATH=${placeholder "out"}" ];
  installTargets = [ "modules_install" ];

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      exec = writeShellScript "yeetmouse.sh" /*bash*/ ''
        "${pname}"
      '';
      type = "Application";
      desktopName = "Yeetmouse GUI";
      comment = "Yeetmouse Configuration Tool";
      icon = "rawaccel";
      categories = [
        "Settings"
        "HardwareSettings"
      ];
    })
  ];

  meta.mainProgram = "yeetmouse";
}
