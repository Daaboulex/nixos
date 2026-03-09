{ inputs, ... }: {
  flake.overlays.default = final: prev: {
    # ReShade shaders for vkBasalt (includes Vibrance, LUT, color grading)
    reshade-shaders = prev.stdenvNoCC.mkDerivation {
      pname = "reshade-shaders";
      version = "unstable-2025-03-06";
      srcs = [
        (prev.fetchFromGitHub {
          owner = "crosire";
          repo = "reshade-shaders";
          rev = "d71489726fa0c732e862e36044abbf7e2bbb6ba1";
          hash = "sha256-87Z+4p4Sx5FcTIvh9cMcHvjySWg5ohHAwvNV6RbLq4A=";
          name = "crosire-reshade-shaders";
        })
        (prev.fetchFromGitHub {
          owner = "CeeJayDK";
          repo = "SweetFX";
          rev = "16d1a42247cb5baaf660120ee35c9a33bb94649c";
          hash = "sha256-h7nqn4aQHomrI/NG0Oj2R9bBT8VfzRGVSZ/CSi/Ishs=";
          name = "sweetfx-shaders";
        })
      ];
      sourceRoot = ".";
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/reshade/{Shaders,Textures}
        # Base ReShade shaders (crosire)
        cp -r crosire-reshade-shaders/Shaders/* $out/share/reshade/Shaders/
        cp -r crosire-reshade-shaders/Textures/* $out/share/reshade/Textures/
        # SweetFX shaders (Vibrance, LiftGammaGain, Tonemap, etc.)
        cp -r sweetfx-shaders/Shaders/SweetFX/* $out/share/reshade/Shaders/
        cp -r sweetfx-shaders/Textures/* $out/share/reshade/Textures/ 2>/dev/null || true
        runHook postInstall
      '';
      meta = with prev.lib; {
        description = "Collection of post-processing shaders for ReShade/vkBasalt (base + SweetFX)";
        homepage = "https://github.com/crosire/reshade-shaders";
        license = licenses.bsd3;
        platforms = platforms.all;
      };
    };
  };
}
