# multiseat — bare-metal systemd-logind multiseat: bind a GPU + a whole USB
# controller (+ optional GPU audio) to an additional seat, and pin each seat's
# user session to a CPU set. Operates at the logind/udev layer, BELOW the
# compositor, so it is display-server-agnostic (works under Wayland or X11) — the
# session-launch layer (display manager / autologin) is the consumer's choice.
# No GPU passthrough: every GPU keeps its native driver (this is NOT a VFIO spec).
#
# A host declares its seats; the mechanism is derived: ID_SEAT udev tagging from
# each seat's PCI addresses, the nvidia master-of-seat workaround (proprietary
# nvidia exposes no /dev/fb*, so logind never auto-promotes its seat), and a
# cgroup-v2 cpuset per seat's user slice.
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
      cfg = config.myModules.hardware.multiseat;

      # Pure resource-disjointness detector (shared CPU/GPU/USB/audio/user/seat-id)
      # — the same logic the eval-multiseat-collisions gate feeds colliding seats to.
      detectCollisions = import ./_multiseat-collisions.nix { inherit lib; };

      # PCI address (0000:05:00.0) → the underscore form udev exposes in the
      # ID_FOR_SEAT property (0000_05_00_0).
      pciTag = a: builtins.replaceStrings [ ":" "." ] [ "_" "_" ] a;
      isPciAddr = a: builtins.match "[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-7]" a != null;

      secondarySeats = lib.filterAttrs (_: s: !s.isPrimary) cfg.seats;

      # udev rules per secondary seat: tag its GPU DRM card + graphics node, its
      # optional GPU audio function, and a whole USB controller. ID_AUTOSEAT on the
      # controller makes every device plugged into it (incl. hotplugged) inherit the
      # seat. nvidia GPUs also get master-of-seat (no framebuffer to auto-promote on).
      mkSeatRules =
        s:
        let
          g = pciTag s.gpu.pciAddress;
          master = lib.optionalString (s.gpu.driver == "nvidia") '', TAG+="master-of-seat"'';
        in
        ''
          TAG=="seat", ENV{ID_FOR_SEAT}=="drm-pci-${g}", ENV{ID_SEAT}="${s.seatId}"${master}
          TAG=="seat", ENV{ID_FOR_SEAT}=="graphics-pci-${g}", ENV{ID_SEAT}="${s.seatId}"
        ''
        + lib.optionalString (s.audioPciAddress != null) ''
          TAG=="seat", ENV{ID_FOR_SEAT}=="sound-pci-${pciTag s.audioPciAddress}", ENV{ID_SEAT}="${s.seatId}"
        ''
        + lib.optionalString (s.usbController != null) ''
          TAG=="seat", ENV{ID_FOR_SEAT}=="pci-${pciTag s.usbController}", ENV{ID_SEAT}="${s.seatId}", ENV{ID_AUTOSEAT}="1"
        ''
        # Specific USB input devices, by idVendor:idProduct. Tagging ONLY these to
        # the seat means every other input device stays on seat0 — the seat sees
        # only the devices declared here, regardless of which port they're in.
        + lib.concatMapStrings (d: ''
          SUBSYSTEM=="input", ATTRS{idVendor}=="${d.vendorId}", ATTRS{idProduct}=="${d.productId}", TAG+="seat", ENV{ID_SEAT}="${s.seatId}"
        '') s.inputDevices;

      # cgroup-v2 cpuset per seat's user slice. AllowedCPUs (not CPUAffinity — the
      # cpuset controller resets the sched-affinity mask; AllowedCPUs is the durable
      # cgroup-native form, inherited by every process in the session incl. Steam +
      # gamemode, which therefore cannot widen past the slice). Slice name = user-<uid>.
      cpuSlices = lib.listToAttrs (
        lib.concatMap (
          s:
          lib.optional (s.cpuset != null) {
            name = "user-${toString config.users.users.${s.user}.uid}";
            value.sliceConfig.AllowedCPUs = s.cpuset;
          }
        ) (lib.attrValues cfg.seats)
      );
    in
    {
      _class = "nixos";

      options.myModules.hardware.multiseat = {
        enable = lib.mkEnableOption "bare-metal systemd-logind multiseat — a second graphical seat bound to its own GPU + USB controller, with per-seat CPU pinning. No GPU passthrough (native drivers); display-server-agnostic";

        seats = lib.mkOption {
          default = { };
          description = ''
            Seat declarations. Exactly one seat sets isPrimary=true — it is the
            implicit seat0 that owns every device not assigned elsewhere, so it gets
            NO udev tagging (only its CPU pinning is applied). Each other seat binds
            its GPU (+ optional audio + a whole USB controller) to its seatId.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                isPrimary = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "The implicit seat0 — emit no ID_SEAT tagging (it owns the unassigned devices), only CPU pinning. Exactly one seat should set this.";
                };
                seatId = lib.mkOption {
                  type = lib.types.str;
                  default = "seat0";
                  example = "seat1";
                  description = "logind seat name for a secondary seat (seat1, seat2, …). Unused when isPrimary.";
                };
                user = lib.mkOption {
                  type = lib.types.str;
                  description = "Login user this seat owns (its session + CPU slice). For a secondary seat with createUser=true the module CREATES this account; for the primary it is the host's existing primaryUser.";
                };
                createUser = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "When true the module CREATES this seat's user account (uid + extraGroups below) — so declaring a seat sets up its user. Use for secondary seats; leave false for the primary (its account is the host's main user, owned by the users module).";
                };
                uid = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  example = 1001;
                  description = "Fixed uid for the created user (required when createUser=true — the cgroup CPU-slice name derives from it).";
                };
                extraGroups = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [
                    "video"
                    "input"
                    "audio"
                  ];
                  description = "Supplementary groups for the created user.";
                };
                cpuset = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "0-7,16-23";
                  description = "AllowedCPUs for this user's systemd slice (CCD pinning). null = no pinning.";
                };
                gpu = {
                  pciAddress = lib.mkOption {
                    type = lib.types.str;
                    example = "0000:05:00.0";
                    description = "PCI address of the seat's GPU (its DRM card).";
                  };
                  driver = lib.mkOption {
                    type = lib.types.enum [
                      "amdgpu"
                      "nvidia"
                      "nouveau"
                      "radeon"
                      "i915"
                    ];
                    description = "Kernel driver bound to the GPU. 'nvidia' adds master-of-seat (proprietary nvidia has no /dev/fb*, so logind won't promote the seat on its own).";
                  };
                };
                audioPciAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "0000:05:00.1";
                  description = "PCI address of the GPU's HDMI/DP audio function to bind to this seat (null = audio stays on seat0).";
                };
                usbController = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "0000:7c:00.4";
                  description = "PCI address of a USB controller bound WHOLE to this seat — every device plugged into it (incl. hotplug) inherits the seat. null = assign inputs elsewhere.";
                };
                inputDevices = lib.mkOption {
                  default = [ ];
                  description = ''
                    Specific USB input devices (by idVendor:idProduct, from `lsusb`)
                    to bind to THIS seat — instead of, or in addition to, a whole
                    usbController. Only the listed devices are tagged to the seat;
                    every other input device stays on seat0, so the seat ignores all
                    inputs except the ones declared here. Use this to pin one mouse
                    (or keyboard) to the seat regardless of which port it occupies.
                  '';
                  example = [
                    {
                      vendorId = "046d";
                      productId = "c539";
                    }
                  ];
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        vendorId = lib.mkOption {
                          type = lib.types.str;
                          example = "046d";
                          description = "USB idVendor — 4 lowercase hex digits (left field of `lsusb`'s ID).";
                        };
                        productId = lib.mkOption {
                          type = lib.types.str;
                          example = "c539";
                          description = "USB idProduct — 4 lowercase hex digits (right field of `lsusb`'s ID).";
                        };
                      };
                    }
                  );
                };
              };
            }
          );
        };
      };

      config = lib.mkIf cfg.enable {
        assertions =
          # Resource-disjointness: nothing claimed by two seats (shared CPU/GPU/USB/
          # audio/user/seat-id). Derived from the pure detector so the build fails
          # closed on any collision — see eval-multiseat-collisions for the proof.
          (lib.map (msg: {
            assertion = false;
            message = "myModules.hardware.multiseat: ${msg}";
          }) (detectCollisions cfg.seats))
          ++ lib.concatLists (
            lib.mapAttrsToList (
              name: s:
              [
                {
                  assertion = config.users.users ? ${s.user} && config.users.users.${s.user}.uid != null;
                  message = "myModules.hardware.multiseat.seats.${name}.user: \"${s.user}\" must be a user with a fixed uid (the cgroup slice name derives from it).";
                }
                {
                  assertion = s.isPrimary || s.seatId != "seat0";
                  message = "myModules.hardware.multiseat.seats.${name}: a secondary seat needs a seatId other than \"seat0\" (e.g. \"seat1\").";
                }
                {
                  assertion = s.isPrimary || isPciAddr s.gpu.pciAddress;
                  message = "myModules.hardware.multiseat.seats.${name}.gpu.pciAddress: must be a valid PCI address DDDD:BB:DD.F. Got \"${s.gpu.pciAddress}\".";
                }
                {
                  assertion = !s.createUser || s.uid != null;
                  message = "myModules.hardware.multiseat.seats.${name}: createUser=true requires a fixed uid (the cgroup CPU-slice name derives from it).";
                }
              ]
              ++ lib.map (d: {
                assertion =
                  builtins.match "[0-9a-f]{4}" d.vendorId != null && builtins.match "[0-9a-f]{4}" d.productId != null;
                message = "myModules.hardware.multiseat.seats.${name}.inputDevices: vendorId/productId must each be 4 lowercase hex digits (from lsusb). Got \"${d.vendorId}:${d.productId}\".";
              }) s.inputDevices
            ) cfg.seats
          );

        services.udev.extraRules = lib.concatStrings (lib.map mkSeatRules (lib.attrValues secondarySeats));

        systemd.slices = cpuSlices;

        # Template a user account per seat that asks for one — so DECLARING a seat sets up
        # its user, with no hand-rolled users.users.* in the host spec. The primary seat
        # leaves createUser=false: its account is the host's main user (the users module).
        users.users = lib.mapAttrs' (
          name: s:
          lib.nameValuePair s.user {
            isNormalUser = true;
            inherit (s) uid;
            description = "Multiseat seat ${name}";
            inherit (s) extraGroups;
            shell = pkgs.zsh;
          }
        ) (lib.filterAttrs (_: s: s.createUser) cfg.seats);
      };
    };
in
{
  flake.modules.nixos.hardware-multiseat = mod;

}
