{ inputs, ... }: {
  flake.nixosModules.hardware-yeetmouse = { config, lib, pkgs, ... }: {
    options.myModules.hardware.yeetmouse = {
      enable = lib.mkEnableOption "YeetMouse input driver";
    };

    imports = [
      ./driver.nix
      ./devices/g502.nix
    ];

    config = lib.mkIf (config.myModules.hardware.yeetmouse.enable || config.myModules.hardware.yeetmouse.devices.g502.enable) {
      hardware.yeetmouse.enable = true;

      services.udev.extraRules = ''
        SUBSYSTEM=="module", KERNEL=="yeetmouse", ACTION=="add", RUN+="${pkgs.runtimeShell} -c 'chmod 0664 /sys/module/yeetmouse/parameters/* && chgrp users /sys/module/yeetmouse/parameters/*'"
      '';

      nixpkgs.overlays = [
        (final: prev: let
          actualKernel = config.boot.kernelPackages.kernel;
          kernelNameLower = lib.toLower (actualKernel.pname or actualKernel.name or "");
          kernelVersionLower = lib.toLower (actualKernel.modDirVersion or "");
          
          kernelUsesLLVM = 
            (builtins.match ".*cachyos.*" kernelNameLower != null) ||
            (builtins.match ".*cachyos.*" kernelVersionLower != null) ||
            (builtins.any (flag: 
              builtins.match ".*LLVM=1.*" (toString flag) != null || 
              builtins.match ".*CC=clang.*" (toString flag) != null
            ) (actualKernel.makeFlags or []));
          
          buildStdenv = if kernelUsesLLVM then final.llvmPackages_latest.stdenv else final.stdenv;
          
          buildMakeFlags = if kernelUsesLLVM then [
            "LLVM=1" "CC=clang" "LD=ld.lld" "KCFLAGS=-Wno-unused-command-line-argument"
          ] else [];
          
        in {
          yeetmouse = (final.callPackage ./package.nix {
            stdenv = buildStdenv;
            kernel = actualKernel;
            kernelModuleMakeFlags = buildMakeFlags;
          }).overrideAttrs (old: {
            src = inputs.yeetmouse-src;
            postPatch = ''
              # Convert informational printk to KERN_INFO
              sed -i 's/printk(/printk(KERN_INFO /g' driver/driver.c
              
              # Convert Error printk to KERN_ERR
              sed -i 's/printk(/printk(KERN_ERR /g' driver/accel_modes.c

              # Fix GUI hardcoded limits for Smoothness (exponent)
              # Allow Jump mode to show 0.00
              sed -i 's/DragFloat("##Exp_Param", \&params\[selected_mode\].exponent, 0.0, 0.01/DragFloat("##Exp_Param", \&params\[selected_mode\].exponent, 0.0, 0.0/g' gui/main.cpp
              sed -i 's/SliderFloat("##Exp_Param", \&params\[selected_mode\].exponent, 0.0, 1/SliderFloat("##Exp_Param", \&params\[selected_mode\].exponent, 0.0, 1/g' gui/main.cpp

              # Hide "Running without root privileges" warning and force has_privilege = true
              sed -i 's/if (getuid()) {/if (false) { \/\/ getuid check disabled/g' gui/main.cpp
              sed -i 's/has_privilege = false;/has_privilege = true; \/\/ forced/g' gui/main.cpp
              sed -i 's/ImGui::GetForegroundDrawList()->AddText(ImVec2(10, ImGui::GetWindowHeight() - 40),/if(false) ImGui::GetForegroundDrawList()->AddText(ImVec2(10, ImGui::GetWindowHeight() - 40),/g' gui/main.cpp
            '';
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ lib.optionals kernelUsesLLVM [ final.llvmPackages_latest.lld ];
            postBuild = if kernelUsesLLVM then ''
              make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL" "CXX=clang++"
            '' else ''
              make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL"
            '';
          });
        })
      ];
    };
  };
}
