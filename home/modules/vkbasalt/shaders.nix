# shaders — ReShade + vkBasalt shader-collection helper (pure Nix, not a module).
# Returns a list of shader collection derivations when called with pkgs.
pkgs:
let
  mkShaderPkg =
    {
      pname,
      src,
      shaderDir ? "Shaders",
      textureDir ? "Textures",
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname src;
      version = "unstable";
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/reshade/{Shaders,Textures}
        if [ -d "${shaderDir}" ]; then
          cp -r ${shaderDir}/* $out/share/reshade/Shaders/
        fi
        if [ -d "${textureDir}" ]; then
          cp -r ${textureDir}/* $out/share/reshade/Textures/
        fi
        runHook postInstall
      '';
    };
in
[
  # Base ReShade shaders (crosire) — CAS, Deband, LUT, SMAA, FXAA
  (mkShaderPkg {
    pname = "reshade-shaders-crosire";
    src = pkgs.fetchFromGitHub {
      owner = "crosire";
      repo = "reshade-shaders";
      rev = "d71489726fa0c732e862e36044abbf7e2bbb6ba1";
      hash = "sha256-87Z+4p4Sx5FcTIvh9cMcHvjySWg5ohHAwvNV6RbLq4A=";
    };
  })
  # SweetFX — Vibrance, LiftGammaGain, Tonemap, Curves, LumaSharpen
  (mkShaderPkg {
    pname = "reshade-shaders-sweetfx";
    src = pkgs.fetchFromGitHub {
      owner = "CeeJayDK";
      repo = "SweetFX";
      rev = "16d1a42247cb5baaf660120ee35c9a33bb94649c";
      hash = "sha256-h7nqn4aQHomrI/NG0Oj2R9bBT8VfzRGVSZ/CSi/Ishs=";
    };
    shaderDir = "Shaders/SweetFX";
  })
  # prod80 — Professional color grading: Shadows/Midtones/Highlights,
  # Selective Color, Color Temperature, Bloom, Film Grain, Sharpening, LUTs
  (mkShaderPkg {
    pname = "reshade-shaders-prod80";
    src = pkgs.fetchFromGitHub {
      owner = "prod80";
      repo = "prod80-ReShade-Repository";
      rev = "1c2ed5b093b03c558bfa6aea45c2087052e99554";
      hash = "sha256-EM9WxpbN0tUB9yjZFwWtY1l8um7jvMfC2eenEl2amF8=";
    };
  })
  # AstrayFX — DLAA (best AA without depth), Smart_Sharp, Clarity, BloomingHDR
  (mkShaderPkg {
    pname = "reshade-shaders-astrayfx";
    src = pkgs.fetchFromGitHub {
      owner = "BlueSkyDefender";
      repo = "AstrayFX";
      rev = "7e6d7bd8e0729a2cee80d26907b8fb27b568d955";
      hash = "sha256-wcNLTGQxkGaQr/N4BCsT+y9pe41oU5Bsen49ofVcGc0=";
    };
  })
  # fubax — FilmicAnamorphSharpen, FilmicSharpen, PerfectPerspective
  (mkShaderPkg {
    pname = "reshade-shaders-fubax";
    src = pkgs.fetchFromGitHub {
      owner = "Fubaxiusz";
      repo = "fubax-shaders";
      rev = "38825ee2e91c257318c5459fe87337e3049351d9";
      hash = "sha256-X9SX/sypZX3QxblncmxLfjFjiNEeIk/yAkqeKz/WzN4=";
    };
  })
  # qUINT — Lightroom color grading, bloom, sharp
  (mkShaderPkg {
    pname = "reshade-shaders-quint";
    src = pkgs.fetchFromGitHub {
      owner = "martymcmodding";
      repo = "qUINT";
      rev = "98fed77b26669202027f575a6d8f590426c21ebd";
      hash = "sha256-nPraJgxDm1N9FIhrv0msI3B3it8uyzk6YoX25WY27gE=";
    };
  })
  # iMMERSE — SMAA, sharpen (qUINT successor by martymcmodding)
  (mkShaderPkg {
    pname = "reshade-shaders-immerse";
    src = pkgs.fetchFromGitHub {
      owner = "martymcmodding";
      repo = "iMMERSE";
      rev = "8fa641ef7af561a52cfc15f43155abd54b095b1f";
      hash = "sha256-U2jCXL+nDKrFdjby/oQ0T0hw0tL6+SJPzSu9IAaXibA=";
    };
  })
  # METEOR — Film grain, NVSharpen, local Laplacian, long exposure, halftone
  (mkShaderPkg {
    pname = "reshade-shaders-meteor";
    src = pkgs.fetchFromGitHub {
      owner = "martymcmodding";
      repo = "METEOR";
      rev = "228e4aa521b34bdf3ad798220a1e59cc4a2a6a95";
      hash = "sha256-iQ8BYWRNCbQuJ9CRSelF+idcKlCtW+172ZrUUAI8F20=";
    };
  })
  # Insane-Shaders — Dehaze, Halftone, BilateralComic, Oilify
  (mkShaderPkg {
    pname = "reshade-shaders-insane";
    src = pkgs.fetchFromGitHub {
      owner = "LordOfLunacy";
      repo = "Insane-Shaders";
      rev = "19397d503e2fbf1ad2cbedb35fbf2ee84a32e3ec";
      hash = "sha256-2tP0huDz+DBe9GusI2levldx4ilSapePjjiUCEGqOn8=";
    };
  })
  # Daodan — ColorIsolation, Comic, RemoveTint, RetroTint, MeshEdges
  (mkShaderPkg {
    pname = "reshade-shaders-daodan";
    src = pkgs.fetchFromGitHub {
      owner = "Daodan317081";
      repo = "reshade-shaders";
      rev = "f01ddb6f3dce6a8fb75ffb9fee878a1489edfc16";
      hash = "sha256-69jgQfuoV7pObUdSFCwDJzvWR8ijAX9W8TzJR+yIl44=";
    };
  })
  # FXShaders — Bloom, tonemapping, color grading
  (mkShaderPkg {
    pname = "reshade-shaders-fxshaders";
    src = pkgs.fetchFromGitHub {
      owner = "luluco250";
      repo = "FXShaders";
      rev = "76365e35c48e30170985ca371e67d8daf8eb9a98";
      hash = "sha256-Ig8LyICXeo60Xq+4AfVh9FV904pMBPoQ0beUSLi48hY=";
    };
  })
  # potatoFX — HDR-compatible camera, color noise, palette effects
  (mkShaderPkg {
    pname = "reshade-shaders-potatofx";
    src = pkgs.fetchFromGitHub {
      owner = "GimleLarpes";
      repo = "potatoFX";
      rev = "f55a022121688ce9e0d4534f676f1300f14dcb90";
      hash = "sha256-z0R0erjzBlfScaBX6IZE/0zQPU8eHph6fAp9fV/acLU=";
    };
  })
  # CShade — CAS, RCAS, FXAA, DLAA, auto-exposure bloom
  (mkShaderPkg {
    pname = "reshade-shaders-cshade";
    src = pkgs.fetchFromGitHub {
      owner = "papadanku";
      repo = "CShade";
      rev = "40d1105e7ae96ecba7860b1672ef91296489c5fe";
      hash = "sha256-OxPN6pouGtV63+qt3aHwyxX4bOl8WeDN4o7u9MqTRq0=";
    };
    shaderDir = "shaders"; # lowercase in this repo
  })
  # ZenteonFX — Film grain, local contrast, sharpening, xenon bloom
  (mkShaderPkg {
    pname = "reshade-shaders-zenteonfx";
    src = pkgs.fetchFromGitHub {
      owner = "Zenteon";
      repo = "ZenteonFX";
      rev = "0f0a290d3f497330f02cc6d56bf5e8d2524efc52";
      hash = "sha256-UCD3LAZ01aXAo/obsmjsTA12pBx09IXozdcJVc8xir0=";
    };
  })
  # HDR shaders — Tone mapping, film grain, CAS/RCAS for HDR, SDR-to-HDR
  (mkShaderPkg {
    pname = "reshade-shaders-hdr";
    src = pkgs.fetchFromGitHub {
      owner = "EndlesslyFlowering";
      repo = "ReShade_HDR_shaders";
      rev = "48ab279bcc433d8218b7f32cfc550a39a408365c";
      hash = "sha256-zWKTBuoeCcUzZsaZX5h9R2dwR72WIKMR2KvC2aFGR3o=";
    };
  })
]
