{ inputs, ... }: {
  flake.overlays.default = final: prev: {
    # ReShade shaders for vkBasalt (includes Vibrance, LUT, color grading)
    reshade-shaders = prev.stdenvNoCC.mkDerivation {
      pname = "reshade-shaders";
      version = "unstable-2025-03-06";
      src = prev.fetchFromGitHub {
        owner = "crosire";
        repo = "reshade-shaders";
        rev = "d71489726fa0c732e862e36044abbf7e2bbb6ba1";
        hash = "sha256-87Z+4p4Sx5FcTIvh9cMcHvjySWg5ohHAwvNV6RbLq4A=";
      };
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/reshade/{Shaders,Textures}
        cp -r Shaders/* $out/share/reshade/Shaders/
        cp -r Textures/* $out/share/reshade/Textures/
        runHook postInstall
      '';
      meta = with prev.lib; {
        description = "Collection of post-processing shaders for ReShade/vkBasalt";
        homepage = "https://github.com/crosire/reshade-shaders";
        license = licenses.bsd3;
        platforms = platforms.all;
      };
    };
  };
}
