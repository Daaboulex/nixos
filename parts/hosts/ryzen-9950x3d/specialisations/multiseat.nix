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
# instead of KWin; nvidia driver 570/575/580. Seat A autologins via greetd on VT1; Seat B
# launches via a direct systemd system unit + PAM (greetd hardcodes XDG_SEAT=seat0 in its
# PAM env, so it can never bind seat1). seat1 has NO VT — VTs belong to seat0; non-seat0
# sessions are always-active.
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
  # (→ the nvidia open-module DRM-revoke crash). MESA_VK_DEVICE_SELECT pins Vulkan to
  # match — the trailing "!" makes the seat's GPU the ONLY device the layer exposes:
  # without it the layer merely reorders, and anything that picks its own adapter
  # (DXVK/vkd3d prefer the largest-VRAM GPU) would render seat B's games on seat A's
  # 9070 XT across the seat boundary.
  mkSession =
    tag:
    { kwinDevices, vulkanId }:
    pkgs.writeShellScript "seat-session-${tag}" ''
      export KWIN_DRM_DEVICES=${kwinDevices}
      export MESA_VK_DEVICE_SELECT=${vulkanId}!
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
        # Device access comes from logind seat ACLs (uaccess), NOT groups: the seat's
        # own card/sound/inputs are ACL'd to its always-active session, and KWin takes
        # input via logind TakeDevice. The classic video/input/audio groups would cross
        # the seat boundary — "input" alone lets this user read seat A's keyboard
        # (root:input 0660, no per-seat ACL on event nodes). uinput: Steam Input's
        # virtual pads — steam's own udev rule is uaccess = seat0-only, so seat B needs
        # the group route (hardware.uinput below). LANDMINE: any uinput writer can
        # synthesize input that udev assigns to seat0 — uinput is not seat-aware; this
        # is inherent to giving a second seat Steam Input.
        extraGroups = [
          "gamemode"
          "uinput"
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

  # Why mkForce: the Rift CV1 HMD + its USB sensors are not seat-split, and
  # Monado would contend with the per-seat GPU pinning above -- VR is a
  # base-profile feature.
  myModules.hardware.riftCv1.enable = lib.mkForce false;
  home-manager.users.${config.myModules.primaryUser}.myModules.home.xrizer.enable = lib.mkForce false;

  # ── Gamemode vs two pinned seats: each user runs their own gamemoded, but
  # amd_x3d_mode is ONE firmware register — seat B's game exiting would flip it to
  # "frequency" mid-game for seat A (last writer wins). The slice cpusets already
  # hard-pin every session process to its CCD, so the flip can't move game threads
  # anyway; the static cpuAmd.x3dVcache.mode="cache" stays as the deterministic
  # preference. pin_cores likewise targets the V-Cache CCD, which for seat B is
  # entirely outside its cgroup cpuset → guaranteed sched_setaffinity EINVAL. ──
  myModules.gaming.gamemode = {
    # Why mkForce: the host enables the desired/default flip + auto-pin for the
    # single-seat profiles; in multiseat both are racy or dead (above) — the slice
    # cpuset is the single source of CPU placement.
    x3dMode = {
      desired = lib.mkForce null;
      default = lib.mkForce null;
    };
    pinCores = lib.mkForce "no";
  };

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

  # ── Sessions: per-seat autologin into Plasma 6 Wayland. Seat A on seat0 via greetd
  # (pinned to VT1 by the module); Seat B on seat1 via a direct system unit — systemd
  # copies the unit's Environment into the PAM env, where pam_systemd reads XDG_SEAT
  # and creates the logind session on seat1. Each launches its seat's GPU-pinned
  # session script (above). ──
  services.displayManager.sddm.enable = lib.mkForce false;
  services.greetd = {
    enable = true; # seat0 / seat A — greetd is pinned to VT1 by the module
    settings.initial_session = {
      user = config.myModules.primaryUser;
      command = "${seatASession}";
    };
  };
  systemd.services.seat1-session = {
    description = "Seat B Plasma session (seat1)";
    after = [
      "systemd-user-sessions.service"
      "systemd-logind.service"
    ];
    wantedBy = [ "graphical.target" ];
    restartIfChanged = false;
    # Crash-loop guard for the documented seat-B coin-flip (KWin-on-nvidia-seat1):
    # 5 attempts inside 60s, then the unit fails closed instead of hammering the GPU
    # forever — `systemctl restart seat1-session` re-arms it. RestartSec also gives
    # the ExecStopPost reap below time to drain the dead session's scope.
    startLimitIntervalSec = 60;
    startLimitBurst = 5;
    serviceConfig = {
      ExecStart = "${seatBSession}";
      # pam_systemd migrates the session tree OUT of this service's cgroup into
      # session-<id>.scope under user-1001.slice (that migration is also what makes
      # the slice's AllowedCPUs apply) — so KillMode can never reap the session's
      # children, and logind's default KillUserProcesses=no leaves a crashed
      # session's Steam alive holding ~/.steam locks + 1660S VRAM into the next
      # attempt. Reap every session of the seat user between attempts instead.
      ExecStopPost = "-+${pkgs.systemd}/bin/loginctl terminate-user ${seatBUser}";
      RestartSec = 3;
      TimeoutStopSec = 15;
      User = seatBUser;
      PAMName = "seat1-session";
      Environment = [
        "XDG_SEAT=seat1"
        "XDG_SESSION_TYPE=wayland"
        "XDG_SESSION_CLASS=user"
      ];
      Restart = "always";
      Type = "simple";
    };
  };
  # startSession → pam_systemd in the stack (the module that reads XDG_SEAT);
  # allowNullPassword covers the promptless autologin. The seat account itself has
  # no password (locked), so this unit is its only door — no getty/ssh login.
  security.pam.services.seat1-session = {
    startSession = true;
    allowNullPassword = true;
  };

  # ── Seat B confinement: a gaming seat, not a console owner. polkit's allow_active
  # default treats EVERY active local session as the machine's owner — on a multiseat
  # box that hands the second seat reboot/power (kills seat A mid-game),
  # loginctl attach-device (re-seat seat A's keyboard to itself), NetworkManager
  # writes, and system-flatpak installs. Downgrade those to admin auth for the seat
  # user: fails closed, but the owner can still authorize at the prompt. User-scope
  # flatpaks (the seat manifest) never touch the gated system helper. ──
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "${seatBUser}" &&
          (/^org\.freedesktop\.login1\.(power-off|reboot|halt|suspend|hibernate|attach-device|flush-devices|set-reboot)/.test(action.id) ||
           action.id.indexOf("org.freedesktop.NetworkManager.") == 0 ||
           action.id.indexOf("org.freedesktop.Flatpak.") == 0)) {
        return polkit.Result.AUTH_ADMIN;
      }
    });
  '';

  # The seat user has no business driving the nix daemon (store-filling builds on
  # the gaming CCDs). trusted-users (root/primary/remotebuild) are implicitly
  # allowed, so the remote-builder path is unaffected.
  nix.settings.allowed-users = [
    "root"
    "@wheel"
  ];

  # ── Two Steam instances at once (one per seat) ──
  # uinput group route for seat B's Steam Input: steam-devices tags /dev/uinput
  # uaccess-only, and uaccess ACLs land on seat0's user — seat B would get no
  # virtual-pad/gyro support. hardware.uinput regroups the node root:uinput 0660
  # (extraRules apply after the steam rules), and the seat user joins the group.
  hardware.uinput.enable = true;
  # Steam's breakpad minidump dir is SHARED across users: whichever Steam creates
  # /tmp/dumps first owns it 0755 and the other seat's Steam fails to write crash
  # dumps from then on. Pre-create it like /tmp itself (sticky, world-writable).
  systemd.tmpfiles.rules = [ "d /tmp/dumps 1777 root root -" ];

  # ── btrfs Steam-library dedup across the two users' homes (bees daemon).
  # The two libraries (~/.local/share/Steam each) live on the root btrfs, so
  # identical game blocks dedup across both users without a shared library dir. ──
  services.beesd.filesystems.root = {
    spec = config.fileSystems."/".device;
    hashTableSizeMB = 2048;
    verbosity = "info";
    # bees pauses its crawl threads while the 1-minute loadavg exceeds the target,
    # so dedup catches up in idle gaps instead of competing with two live game
    # seats for CPU + NVMe (its default worker count scales with nproc = 32).
    extraOptions = [
      "--loadavg-target"
      "5.0"
    ];
  };

  # ── Scheduler: pin lavd for multiseat even if the base host ever drifts to
  # another scheduler (base currently matches). The cpuset slices already
  # hard-pin each seat's process tree to its CCD, so LLC-aware alternatives
  # (bpfland) add nothing here — lavd's latency-focused virtual-deadline
  # scheduling (lower input-to-frame delay) is the fit when cache placement
  # is enforced by cgroup. ──
  myModules.tuning.performance.scx.scheduler = lib.mkForce "scx_lavd";
  myModules.tuning.performance.scx.extraArgs = lib.mkForce [ ];

  # No passthrough here: vfio.passthrough stays off (base default), both GPUs keep
  # native drivers, nvidia stays enabled for seat B (NOT disabled as in the vfio specs).
}
