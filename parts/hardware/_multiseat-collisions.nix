# _multiseat-collisions — pure collision detector for myModules.hardware.multiseat
# seat declarations. `seats` (the option's attrset) → a list of human-readable
# violation messages; an empty list means the seats are collision-free.
#
# ONE source of truth, consumed twice (single-source-by-derivation): the multiseat
# module maps each message to a failing eval-time assertion, and the
# `eval-multiseat-collisions` gate feeds it deliberately-colliding seats to prove
# the guard fires. A "collision" = any resource that MUST be exclusive to one seat
# being claimed by two: a CPU, a GPU, a USB controller, an audio device, a login
# user, or a (secondary) seat-id. Pure over the seat attrset — no `config` needed,
# so it is trivially testable in isolation.
{ lib }:
seats:
let
  seatList = lib.attrValues seats;

  # "0-7,16-23" → [ 0 1 … 7 16 … 23 ]. The cpuset grammar the systemd slice uses.
  parseCpuset =
    s:
    lib.concatMap (
      part:
      let
        m = builtins.match "([0-9]+)-([0-9]+)" part;
      in
      if m != null then
        lib.range (lib.toInt (builtins.elemAt m 0)) (lib.toInt (builtins.elemAt m 1))
      else
        [ (lib.toInt part) ]
    ) (lib.splitString "," s);

  # Generic: given a label and a function seat→[items], report any item that more
  # than one seat claims. Works for ints (CPUs) and strings (PCI addrs / users).
  dupsOf =
    label: itemsOf:
    let
      all = lib.concatMap itemsOf seatList;
      dups = lib.unique (lib.filter (x: lib.count (y: y == x) all > 1) all);
    in
    lib.optional (
      dups != [ ]
    ) "${label} claimed by more than one seat: ${lib.concatStringsSep ", " (map toString dups)}";

  cpuDups = dupsOf "CPU(s)" (s: lib.optionals (s.cpuset != null) (parseCpuset s.cpuset));
  deviceDups = dupsOf "PCI device(s)" (
    s:
    [ s.gpu.pciAddress ]
    ++ lib.optional (s.audioPciAddress != null) s.audioPciAddress
    ++ lib.optional (s.usbController != null) s.usbController
  );
  userDups = dupsOf "login user(s)" (s: [ s.user ]);
  seatIdDups = dupsOf "secondary seatId(s)" (s: lib.optional (!s.isPrimary) s.seatId);
  inputDeviceDups = dupsOf "input device(s)" (
    s: map (d: "${d.vendorId}:${d.productId}") s.inputDevices
  );

  primaryCount = lib.count (s: s.isPrimary) seatList;
  # Exactly one primary when seats are declared: zero leaves input devices
  # unowned (no implicit seat0), more than one collides on seat0. Empty seats
  # (multiseat off) are exempt -- the guard is `seatList != []`.
  primaryDup = lib.optional (
    seatList != [ ] && primaryCount != 1
  ) "need exactly one seat with isPrimary=true (the implicit seat0); found ${toString primaryCount}";
in
cpuDups ++ deviceDups ++ userDups ++ seatIdDups ++ inputDeviceDups ++ primaryDup
