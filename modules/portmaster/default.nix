{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.security.portmaster;
  # Note: Portmaster downloads pre-built binaries which may use AVX2.
  # On Ivy Bridge (x86-64-v2), if segfaults occur, the binary itself needs to be rebuilt
  # or obtained from a source that doesn't use AVX2 instructions.
  glibcInterp = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";
  commonLibs = lib.makeLibraryPath [
    pkgs.glibc pkgs.openssl pkgs.zlib pkgs.libffi pkgs.glib pkgs.gtk3
    pkgs.nss pkgs.nspr pkgs.dbus pkgs.expat pkgs.cups pkgs.alsa-lib
    pkgs.libdrm pkgs.libgbm pkgs.mesa pkgs.libxkbcommon pkgs.pango pkgs.cairo pkgs.atk pkgs.at-spi2-core
    pkgs.xorg.libX11 pkgs.xorg.libXext pkgs.xorg.libXrandr pkgs.xorg.libXfixes pkgs.xorg.libXcomposite pkgs.xorg.libXdamage pkgs.xorg.libxcb
    pkgs.systemd pkgs.libxshmfence pkgs.libglvnd
    pkgs.brotli pkgs.libdatrie pkgs.libxml2 pkgs.json-glib pkgs.libjpeg pkgs.bzip2 pkgs.graphite2
    pkgs.xorg.libXinerama pkgs.xorg.libXcursor pkgs.libcap pkgs.gmp pkgs.nettle pkgs.libtasn1
    pkgs.libunistring pkgs.libidn2 pkgs.p11-kit pkgs.xorg.libXdmcp pkgs.xorg.libXau pkgs.xorg.libXrender
    pkgs.freetype pkgs.libpng pkgs.libthai pkgs.xorg.libXi pkgs.libepoxy pkgs.fribidi pkgs.fontconfig
    pkgs.harfbuzz pkgs.gnutls pkgs.avahi pkgs.libselinux pkgs.pcre2
    pkgs.libuv pkgs.tinysparql pkgs.stdenv.cc.cc.lib
  ];
  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/safing/portmaster-packaging/master/linux/portmaster_logo.png";
    sha256 = "0mx9j9xchbv84fa9rz04jqmpq8hy7hv64dxmsf3az515jljjdc7c";
  };
  rpath = lib.makeLibraryPath [ pkgs.ungoogled-chromium pkgs.chromium ];
  patchBins = pkgs.writeShellScriptBin "portmaster-patch-binaries" ''
    set -eu
    DATA_DIR="${cfg.dataDir}"
    if [ -d "$DATA_DIR/updates" ]; then
      find "$DATA_DIR/updates" -type f -perm -111 -print0 | while IFS= read -r -d $'\0' bin; do
        ${pkgs.patchelf}/bin/patchelf --set-interpreter "${glibcInterp}" --set-rpath "\$ORIGIN:${rpath}:${commonLibs}" "$bin" || true
      done
    fi
    if [ -f "$DATA_DIR/portmaster-start" ]; then
      ${pkgs.patchelf}/bin/patchelf --set-interpreter "${glibcInterp}" --set-rpath "\$ORIGIN:${rpath}:${commonLibs}" "$DATA_DIR/portmaster-start" || true
    fi
  '';
  appWrapper = pkgs.writeShellScriptBin "portmaster-ui" ''
    export LD_LIBRARY_PATH="${cfg.dataDir}:${pkgs.ungoogled-chromium}/lib:${pkgs.ungoogled-chromium}/lib/chromium:${pkgs.ungoogled-chromium}/libexec/chromium:${pkgs.chromium}/lib:${pkgs.chromium}/lib/chromium:${pkgs.chromium}/libexec/chromium:${commonLibs}:/run/opengl-driver/lib"
    install -d -m 0777 "${cfg.dataDir}/logs/start" "${cfg.dataDir}/logs/app"
    if [ ! -f "${cfg.dataDir}/libffmpeg.so" ]; then
      for p in "${pkgs.ungoogled-chromium}/lib/libffmpeg.so" "${pkgs.ungoogled-chromium}/lib/chromium/libffmpeg.so" "${pkgs.ungoogled-chromium}/libexec/chromium/libffmpeg.so" "${pkgs.chromium}/lib/libffmpeg.so" "${pkgs.chromium}/lib/chromium/libffmpeg.so" "${pkgs.chromium}/libexec/chromium/libffmpeg.so"; do
        if [ -f "$p" ]; then ln -sf "$p" "${cfg.dataDir}/libffmpeg.so"; break; fi
      done
    fi
    exec "${cfg.dataDir}/portmaster-start" app --data "${cfg.dataDir}" "$@"
  '';
  notifierWrapper = pkgs.writeShellScriptBin "portmaster-notifier" ''
    export LD_LIBRARY_PATH="${cfg.dataDir}:${pkgs.ungoogled-chromium}/lib:${pkgs.ungoogled-chromium}/lib/chromium:${pkgs.ungoogled-chromium}/libexec/chromium:${pkgs.chromium}/lib:${pkgs.chromium}/lib/chromium:${pkgs.chromium}/libexec/chromium:${commonLibs}:/run/opengl-driver/lib"
    install -d -m 0777 "${cfg.dataDir}/logs/start" "${cfg.dataDir}/logs/app"
    if [ ! -f "${cfg.dataDir}/libffmpeg.so" ]; then
      for p in "${pkgs.ungoogled-chromium}/lib/libffmpeg.so" "${pkgs.ungoogled-chromium}/lib/chromium/libffmpeg.so" "${pkgs.ungoogled-chromium}/libexec/chromium/libffmpeg.so" "${pkgs.chromium}/lib/libffmpeg.so" "${pkgs.chromium}/lib/chromium/libffmpeg.so" "${pkgs.chromium}/libexec/chromium/libffmpeg.so"; do
        if [ -f "$p" ]; then ln -sf "$p" "${cfg.dataDir}/libffmpeg.so"; break; fi
      done
    fi
    exec "${cfg.dataDir}/portmaster-start" notifier --data "${cfg.dataDir}" "$@"
  '';
  desktopItem = pkgs.makeDesktopItem {
    name = "portmaster";
    desktopName = "Portmaster";
    exec = "${appWrapper}/bin/portmaster-ui";
    terminal = false;
    categories = [ "Network" "Security" ];
    icon = icon;
  };
  portalKDE = lib.attrByPath [ "kdePackages" "xdg-desktop-portal-kde" ] pkgs (lib.attrByPath [ "xdg-desktop-portal-kde" ] pkgs null);
in {
  options.myModules.security.portmaster.enable = lib.mkEnableOption "Enable Portmaster";
  options.myModules.security.portmaster.dataDir = lib.mkOption { type = lib.types.str; default = "/opt/safing/portmaster"; };
  options.myModules.security.portmaster.ui.enable = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.security.portmaster.notifier.enable = lib.mkOption { type = lib.types.bool; default = false; };
  config = lib.mkIf cfg.enable {
    # Portmaster autostarts by default if ui or notifier is enabled.
    # This module manages an impure, auto-updating binary from Safing.
    systemd.services.portmaster-core = {
      description = "Portmaster Core";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.iptables pkgs.nftables pkgs.iproute2 pkgs.coreutils ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        
        # Clean up stale iptables rules before starting (in case of previous crash)
        ExecStartPre = [
          # First: Clean any stale iptables rules from previous crash
          "${pkgs.bash}/bin/bash -c '${pkgs.iptables}/bin/iptables -F C17 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -F C170 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -t nat -F C17 2>/dev/null || true'"
          # Second: Standard Portmaster setup
          ''${pkgs.bash}/bin/bash -lc 'set -e; mkdir -p ${cfg.dataDir}; if [ ! -x "${cfg.dataDir}/portmaster-start" ]; then ${pkgs.curl}/bin/curl -fsSL -o "${cfg.dataDir}/portmaster-start" https://updates.safing.io/latest/linux_amd64/start/portmaster-start && chmod a+x "${cfg.dataDir}/portmaster-start"; fi; "${cfg.dataDir}/portmaster-start" --data "${cfg.dataDir}" update; ${patchBins}/bin/portmaster-patch-binaries; if [ ! -f "${cfg.dataDir}/libffmpeg.so" ]; then for p in "${pkgs.ungoogled-chromium}/lib/libffmpeg.so" "${pkgs.ungoogled-chromium}/lib/chromium/libffmpeg.so" "${pkgs.ungoogled-chromium}/libexec/chromium/libffmpeg.so"; do if [ -f "$p" ]; then ln -sf "$p" "${cfg.dataDir}/libffmpeg.so"; break; fi; done; fi' ''
        ];
        
        ExecStart = ''"${cfg.dataDir}/portmaster-start" core --data "${cfg.dataDir}"'';
        
        # Clean up iptables on stop/failure to prevent network lockout
        ExecStopPost = "${pkgs.bash}/bin/bash -c '${pkgs.iptables}/bin/iptables -F 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -X 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -t nat -F 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -t nat -X 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -t mangle -F 2>/dev/null || true; ${pkgs.iptables}/bin/iptables -t mangle -X 2>/dev/null || true; rm -f ${cfg.dataDir}/core-lock.pid 2>/dev/null || true'";
        
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStartSec = "10m";
        TimeoutStopSec = "30s";
      };
    };
    xdg.portal.enable = lib.mkIf cfg.ui.enable true;
    xdg.portal.extraPortals = lib.mkIf cfg.ui.enable ((lib.optional (portalKDE != null) portalKDE) ++ [ pkgs.xdg-desktop-portal-gtk ]);
    systemd.user.services.portmaster-app = lib.mkIf cfg.ui.enable {
      description = "Portmaster App";
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${appWrapper}/bin/portmaster-ui";
        Restart = "on-failure";
      };
    };
    systemd.user.services.portmaster-notifier = lib.mkIf cfg.notifier.enable {
      description = "Portmaster Notifier";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${notifierWrapper}/bin/portmaster-notifier";
        Restart = "on-failure";
      };
    };
    environment.systemPackages =
      lib.optionals cfg.enable [ pkgs.iptables pkgs.nftables pkgs.iproute2 ]
      ++ lib.optionals cfg.ui.enable [ appWrapper desktopItem pkgs.webkitgtk_4_1 pkgs.libayatana-appindicator ]
      ++ lib.optionals cfg.notifier.enable [ notifierWrapper ];
  };
}