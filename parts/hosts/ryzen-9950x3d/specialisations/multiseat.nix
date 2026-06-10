# multiseat — two bare-metal Wayland gaming seats, NO VFIO.
# Boot entry "ryzen-9950x3d-multiseat". Two people game natively at once on one
# box — NOT virtualisation, no passthrough (both GPUs keep their native drivers).
# systemd-logind splits the hardware into two independent seats:
#   Seat A (user, seat0): RX 9070 XT (03:00.0) + CCD0 (V-Cache) + the Ducky/Logitech
#     + GoXLR/Stream Deck. Full KDE Plasma 6 Wayland — amdgpu is rock-solid on Wayland.
#   Seat B (user "seat", logind seat1): GTX 1660S (05:00.0) + its HDMI audio (05:00.1) + the
#     whole GREATHTEK USB controller (7c:00.4 — any kb/mouse on it) + CCD1. Full KDE
#     Plasma 6 Wayland (user's choice), pinned to the nvidia card via KWIN_DRM_DEVICES.
#
# ⚠ LIVE-VALIDATION FRONTIER + HIGHEST RISK: Seat B = Plasma on
# the nvidia secondary seat is the FRAGILE path — KWin enumerates ALL DRM nodes ignoring
# the logind seat (KDE#511022) and nvidia's open-module atomic-modeset "Permission denied"
# (#990, still broken on driver 580). The per-seat KWIN_DRM_DEVICES export below is the
# MANDATORY mitigation (pins each seat's KWin to its own card). Seat A (amdgpu) is solid;
# Seat B may crash-loop — fallback ladder: a wlroots compositor (Hyprland/cage) for seat B
# instead of KWin; nvidia driver 570/575/580. Both seats autologin via greetd (no multiseat
# DM greeter → dodges sddm#2146); seat1's VT below is a placeholder to verify at the machine.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  seatBUser = "seat";
  plasma = lib.getExe' pkgs.kdePackages.plasma-workspace "startplasma-wayland";
  # Per-seat Plasma 6 Wayland launcher. The GPU env is injected AT LAUNCH (not via HM
  # session vars, which a Wayland session may not source before KWin starts):
  # KWIN_DRM_DEVICES pins THIS seat's KWin to its own card — MANDATORY because KWin
  # still enumerates every DRM node regardless of the logind seat (KDE#511022), so
  # without it seat B's KWin would grab the AMD and seat A's would touch the nvidia
  # (→ the nvidia open-module DRM-revoke crash). MESA_VK_DEVICE_SELECT pins Vulkan to match.
  mkSession =
    tag:
    { kwinDevices, vulkanId }:
    pkgs.writeShellScript "seat-session-${tag}" ''
      export KWIN_DRM_DEVICES=${kwinDevices}
      export MESA_VK_DEVICE_SELECT=${vulkanId}
      exec ${plasma}
    '';
  seatASession = mkSession "a" {
    kwinDevices = "/dev/dri/by-gpu/amd:/dev/dri/by-gpu/igpu";
    vulkanId = "1002:7550";
  };
  seatBSession = mkSession "b" {
    kwinDevices = "/dev/dri/by-gpu/nvidia";
    vulkanId = "10de:21c4";
  };
  # Second greetd instance for seat1 (one greetd per seat is the supported
  # multiseat pattern). VT 8 is a placeholder — verify seat1's VT live with
  # `loginctl seat-status seat1` and adjust.
  seatBGreetdToml = (pkgs.formats.toml { }).generate "greetd-seat1.toml" {
    terminal.vt = 8;
    initial_session = {
      user = seatBUser;
      command = "${seatBSession}";
    };
    default_session = {
      user = seatBUser;
      command = "${seatBSession}";
    };
  };
in
{
  # ── Seat hardware split (the reusable mechanism — udev ID_SEAT + cpuset) ──
  myModules.hardware.multiseat = {
    enable = true;
    seats = {
      seat-a = {
        isPrimary = true; # seat0 — owns every device not tagged to seat1
        user = "user";
        cpuset = "0-7,16-23"; # CCD0 = 96MB V-Cache — the primary gamer
        gpu = {
          pciAddress = "0000:03:00.0";
          driver = "amdgpu";
        };
      };
      seat-b = {
        seatId = "seat1";
        user = seatBUser;
        cpuset = "8-15,24-31"; # CCD1
        gpu = {
          pciAddress = "0000:05:00.0"; # GTX 1660S
          driver = "nvidia"; # → adds master-of-seat (nvidia has no /dev/fb*)
        };
        audioPciAddress = "0000:05:00.1"; # 1660S HDMI audio → seat B's pipewire
        usbController = "0000:7c:00.4"; # GREATHTEK — kb/mouse plugged here → seat B
        # To bind ONLY a specific mouse (+ keyboard) to seat B and ignore every
        # other pointer, drop usbController above and list the devices here by
        # idVendor:idProduct (from `lsusb`); only tagged devices join the seat:
        #   inputDevices = [ { vendorId = "xxxx"; productId = "yyyy"; } ];
        # The module CREATES this seat's user account (no hand-rolled users.users.* here).
        createUser = true;
        uid = 1001;
        extraGroups = [
          "video"
          "input"
          "audio"
          "gamemode"
        ];
      };
    };
  };

  # ── Seat B home-manager: the lean per-user manifest (home/users/seat) on top of
  # the shared module catalog. By construction it omits seat A's device-owner daemons
  # (goxlr/streamcontroller/coolercontrol/lact), dev/VM tooling, and mouse-accel —
  # see home/users/seat/default.nix (collision audit). ──
  # Reference the shared HM catalog via the flake MODULE REGISTRY and the seat manifest
  # via the flake SOURCE — never fragile ../../../../ relative paths (which couple this
  # file to the tree layout and break if it moves).
  home-manager.users.${seatBUser}.imports = builtins.attrValues inputs.self.modules.homeManager ++ [
    "${inputs.self}/home/users/seat"
  ];

  # ── No system-wide GPU Vulkan pin: each seat's launcher sets MESA_VK_DEVICE_SELECT
  # for its own card (above), so the system-wide AMD pin — which would otherwise force
  # BOTH seats onto the AMD card — is dropped here. ──
  myModules.hardware.gpuAmd.vulkanDeviceId = lib.mkForce null;

  # ── Mouse accel: scope yeetmouse to Seat A's mouse only ──
  # yeetmouse is a GLOBAL kernel input_handler (one curve for every mouse), so in
  # multiseat it would also grab Seat B's mouse. onlyDevices restricts its
  # driver_match to Seat A's Logitech (every id it enumerates as), leaving Seat B's
  # mouse flat. Set ONLY here — the base/other profiles keep yeetmouse global.
  # Reuses the single-source G502 product ids; confirm the live id on the box via
  # /proc/bus/input/devices if Seat A's pointer ever loses its curve here.
  myModules.input.yeetmouse.onlyDevices =
    let
      g = config.myModules.input.yeetmouse.devices.g502;
    in
    [
      {
        vendorId = "046d";
        productId = g.wiredProductId;
      }
      {
        vendorId = "046d";
        productId = g.wirelessProductId;
      }
      {
        vendorId = "046d";
        productId = "407f"; # kernel-exposed input id for the Lightspeed mouse
      }
    ];

  # ── Sessions: per-seat autologin into Plasma 6 Wayland, NO multiseat DM greeter
  # (dodges sddm#2146). Seat A on seat0 via greetd; Seat B on seat1 via a second
  # greetd instance. Each launches its seat's GPU-pinned session script (above). ──
  services.displayManager.sddm.enable = lib.mkForce false;
  services.greetd = {
    enable = true; # seat0 / seat A — greetd is pinned to VT1 by the module
    settings.initial_session = {
      user = config.myModules.primaryUser;
      command = "${seatASession}";
    };
  };
  systemd.services.greetd-seat1 = {
    description = "greetd for seat1 (Seat B Plasma session)";
    after = [ "systemd-user-sessions.service" ];
    wantedBy = [ "graphical.target" ];
    conflicts = [ "getty@tty8.service" ];
    restartIfChanged = false;
    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.greetd "greetd"} --config ${seatBGreetdToml}";
      Restart = "always";
      Type = "idle";
    };
  };

  # ── btrfs Steam-library dedup across the two users' homes (bees daemon).
  # The two libraries (~/.local/share/Steam each) live on the root btrfs, so
  # identical game blocks dedup across both users without a shared library dir. ──
  services.beesd.filesystems.root = {
    spec = config.fileSystems."/".device;
    hashTableSizeMB = 2048;
    verbosity = "info";
  };

  # No passthrough here: vfio.passthrough stays off (base default), both GPUs keep
  # native drivers, nvidia stays enabled for seat B (NOT disabled as in the vfio specs).
}
