# vfio-amd — max-power single-VM gaming specialisation.
# Boot entry "ryzen-9950x3d-vfio-amd". The 9070 XT is captured by vfio-pci at boot →
# win11-amd (CCD0 V-Cache); the host desktop runs on the iGPU + 1660S (use the
# monitor's input switch as a KVM). Under static capture the dGPU is never a KWin DRM
# node, so KDE Bug 515835 cannot occur. evdev Ctrl+Ctrl shares keyboard/mouse host↔guest.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Shared passthrough machinery: static capture + ACS split + br0 + host-gaming-off.
  imports = [ ./_common-vfio.nix ];

  # 9070 XT is captured by vfio-pci at boot → no DRM node. Host renders AND scans out on
  # the 1660S (the display is cabled to it via HDMI-A-2); the iGPU is a secondary reserve.
  # Render on the scanout GPU to avoid the reverse-PRIME hop (iGPU render → copy to 1660S)
  # that blew the 240Hz frame deadline → libinput "lagging behind" → mouse stutter (both
  # GPUs were <5% busy, so the cross-GPU copy latency, not GPU load, was the cause). The
  # aliases are cardN-independent: the 1660S renumbers (card2→card1) once 9070 XT is vfio-pci.
  myModules.vfio.sessionGpuDevices = lib.mkForce [
    "/dev/dri/by-gpu/nvidia" # 1660S (05:00.0) — PRIMARY render + scanout (host display)
    "/dev/dri/by-gpu/igpu" # iGPU (7c:00.0) — secondary reserve
  ];
  # Plymouth / early-boot fbcon on the 1660S. In THIS profile nvidia is the host head
  # (the 9070 XT is vfio-bound), so the nvidia DRM modules must be in the initrd —
  # otherwise the only early KMS node is amdgpu (the iGPU, no monitor cabled) and the
  # splash + LUKS prompt never appear on the cabled 1660S. normal/vfio-nvidia/vfio-all
  # leave this off (amdgpu drives their head; here nvidia is disabled in the latter two).
  myModules.hardware.gpuNvidia.initrd.enable = lib.mkForce true;
  # win11-amd is CCD0 (V-Cache) → host stays on CCD1 (base hostCpuMask, no override).
  # No Looking Glass (disabled globally) — view the VM by switching the monitor
  # input to the 9070 XT (which the VM drives).
  myModules.vfio.vms.win11-amd.enable = lib.mkForce true;
  # Autostart DISABLED until win11-amd is validated end-to-end (boots Windows, evdev
  # Ctrl+Ctrl toggles, the 9070 XT outputs a display). Autostarting a not-yet-working VM
  # TRAPS the host: it grabs the evdev keyboard/mouse at boot with no usable guest display
  # to release them. Flip back to true once the guest is known-good.
  myModules.vfio.autostart = lib.mkForce false;
  # RAM split for this single-VM gaming profile: win11-amd gets 44 GiB, the Linux host keeps
  # ~16 GiB (desktop ~7 GiB + QEMU overhead + zram). Boot-static reserves the pool at boot —
  # the dynamic per-VM hook left nr_hugepages = 0 → QEMU "unable to map backing store for
  # guest RAM"; with autostart the VM always runs, so the reservation is used, not wasted.
  # ⚠ bootStatic HARD-reserves 44 GiB, so the host is capped at ~16 GiB (zram backs spillover).
  myModules.vfio.vms.win11-amd.memory.count = lib.mkForce 44; # GiB (base is 32; this profile only)
  myModules.vfio.hugepages.size = lib.mkForce "1G"; # 1 GiB pages — fewer TLB misses than 2 MiB
  myModules.vfio.hugepages.count = lib.mkForce 44; # 44 × 1 GiB = 44 GiB (must match the VM)
  myModules.vfio.hugepages.bootStatic = lib.mkForce true; # 1 GiB pages must be reserved at boot (runtime alloc fragments)
  # Core isolation — dedicate CCD0 (win11-amd's 16 vCPUs) to the guest: remove from the
  # host scheduler (domain), keep managed IRQs off it, stop the timer tick + offload RCU,
  # and steer all device IRQs to the host CCD1. Near bare-metal frametimes. Host + QEMU
  # emulator/IO run on CCD1 (8-15,24-31).
  boot.kernelParams = [
    "isolcpus=domain,managed_irq,0-7,16-23"
    "nohz_full=0-7,16-23"
    "rcu_nocbs=0-7,16-23"
    "irqaffinity=8-15,24-31"
  ];
  # Orphaned/unusable here — the RX 9070 XT is passed to win11-amd and gaming happens
  # in-guest, so these host daemons have no device / no purpose in this profile:
  myModules.hardware.gpuAmd.lact.enable = lib.mkForce false; # 9070 XT undervolt daemon — device gone
  myModules.gaming.steam.enable = lib.mkForce false;
  myModules.gaming.gamescope.enable = lib.mkForce false;
  myModules.gaming.gamemode.enable = lib.mkForce false;
  myModules.gaming.rocksmith.enable = lib.mkForce false;
}
