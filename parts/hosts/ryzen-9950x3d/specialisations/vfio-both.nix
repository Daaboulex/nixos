# vfio-both -- both VMs at once, thin headless iGPU host.
# Boot entry "ryzen-9950x3d-vfio-both". BOTH dGPUs are captured by vfio-pci at
# boot (static, NOT libvirt-managed -- the most reliable path for two parallel
# autostarted guests) and both Windows VMs autostart: win11-amd on the RX 9070 XT
# (the main gaming monitor), win11-nvidia on the GTX 1660S (the vertical monitor,
# a 2nd person). Linux is HEADLESS on the iGPU (SSH + the iGPU TTY for recovery;
# no Linux login is needed to use either VM). The keyboard/mouse + GoXLR + Stream
# Deck are USB-passed into the amd VM; the SupremeFX + GREATHTEK port go to the
# nvidia VM. Whole-CCD-per-VM: 14 vCPU + 28 GB each, the 8th core of each CCD runs
# that VM's QEMU emulator/IO. Hugepages are boot-static (one pool can't be sized
# dynamically for two parallel VMs). On `systemctl poweroff` libvirt-guests
# ACPI-shuts both guests in parallel before the host powers off.
#
# This is the complement of vfio-dynamic (one VM at a time, dynamic resources,
# seamless desktop): vfio-both trades the live desktop + dynamic reclaim for two
# simultaneous guests. It is the consumer of perVmStealthSerials + autostart +
# hugepages.bootStatic.
#
# WIP: win11-amd's AMD driver does not yet install (known Navi 48 problem -- memory
# note 9070xt-vfio-corruption), so the amd seat boots but has no GPU acceleration
# until that is fixed; the nvidia seat is fully functional.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # -- Passthrough machinery: shared fragment; here device-binding derives the
  # UNION of both VMs' gpu.staticIds (9070 XT + all four 1660S functions). --
  imports = [
    ./_common-vfio.nix
  ];
  # Both dGPUs are handed to guests here. Take the host drivers out of the way
  # via the vendor-aware gpu passthrough options (replaces the old _pass-* fragment
  # files): nvidia is fully removed + nouveau blacklisted (no nvidia iGPU); amdgpu
  # stays loaded for the host iGPU while the 9070 XT is captured per-device by
  # vfio-pci.ids static binding (gpuAmd.passthrough just drops LACT for the passed
  # card). See parts/hardware/gpu-{nvidia,amd}.nix.
  myModules.hardware.gpuNvidia.passthrough.enable = lib.mkForce true;
  myModules.hardware.gpuAmd.passthrough.enable = lib.mkForce true;
  # Enable BOTH VMs (both defined disabled at base).
  myModules.vfio.vms.win11-amd.enable = lib.mkForce true;
  myModules.vfio.vms.win11-nvidia.enable = lib.mkForce true;
  # Two VMs running at once would otherwise present identical board/BIOS serials
  # (a fidelity tell) -- give each a name-derived unique SMBIOS serial set (R2).
  # (Enforced by an eval assertion: >1 co-running VM under stealth requires this.)
  myModules.vfio.perVmStealthSerials = lib.mkForce true;

  # -- Headless iGPU host --
  # The two physical monitors are driven by the VMs' passed GPUs; the host renders
  # only on the iGPU (SSH + iGPU TTY recovery head). The passed GPUs have no DRM
  # node under static capture, so the list names only the iGPU.
  myModules.vfio.sessionGpuDevices = lib.mkForce [ "/dev/dri/by-gpu/igpu" ];
  # evdev OFF: the keyboard + mouse are USB-passed surgically to the amd VM here
  # (not shared host<->guest via evdev -- there is no host desktop to share with).
  myModules.vfio.evdev.enable = lib.mkForce false;

  # -- Autostart + graceful parallel power-off --
  # NixVirt active=true + the libvirt autostart flag bring both VMs up at boot;
  # libvirt-guests ACPI-shuts both in parallel on host poweroff (base.autostart).
  myModules.vfio.autostart = lib.mkForce true;

  # -- CPU partition: a whole CCD per VM, no thread crosses CCDs --
  # amd VM = CCD0 (V-Cache): 14 vCPU on cores 0-6 + threads 16-22, with the CCD's
  # 8th core (7 / thread 23) reserved for its own QEMU emulator + IO thread, so
  # the vCPUs stay fully cache-local and contention-free under dual-VM load.
  myModules.vfio.vms.win11-amd.memory.count = lib.mkForce 28; # 64 GB host can't fit 32+32 (locked DMA RAM)
  myModules.vfio.vms.win11-amd.vcpu.count = lib.mkForce 14; # CCD0 minus the emulator/IO core
  myModules.vfio.vms.win11-amd.vcpu.pinning = lib.mkForce [
    0
    1
    2
    3
    4
    5
    6
    16
    17
    18
    19
    20
    21
    22
  ];
  myModules.vfio.vms.win11-amd.vcpu.emulatorPin = lib.mkForce "7"; # CCD0 8th physical core
  myModules.vfio.vms.win11-amd.vcpu.iothreadPin = lib.mkForce "23"; # CCD0 8th SMT thread
  # nvidia VM = CCD1: 14 vCPU on cores 8-14 + threads 24-30, 8th core (15 / 31)
  # reserved for its emulator/IO.
  myModules.vfio.vms.win11-nvidia.memory.count = lib.mkForce 28; # see amd note (locked DMA RAM)
  myModules.vfio.vms.win11-nvidia.vcpu.count = lib.mkForce 14; # CCD1 minus the emulator/IO core
  myModules.vfio.vms.win11-nvidia.vcpu.pinning = lib.mkForce [
    8
    9
    10
    11
    12
    13
    14
    24
    25
    26
    27
    28
    29
    30
  ];
  myModules.vfio.vms.win11-nvidia.vcpu.emulatorPin = lib.mkForce "15"; # CCD1 8th physical core
  myModules.vfio.vms.win11-nvidia.vcpu.iothreadPin = lib.mkForce "31"; # CCD1 8th SMT thread

  # -- Boot-static 1 GiB hugepages sized for BOTH VMs --
  # 2x28 GiB = 56 x 1 GiB pages, reserved at boot (a single dynamic hook pool can't
  # serve two parallel VMs); a oneshot asserts the pool before autostart.
  # (Enforced by an eval assertion: >1 co-running VM requires hugepages.bootStatic.)
  myModules.vfio.hugepages.bootStatic = lib.mkForce true;
  myModules.vfio.hugepages.size = lib.mkForce "1G";
  myModules.vfio.hugepages.count = lib.mkForce 56; # 2 x 28 x 1 GiB = 56 GiB
  # Core isolation -- dedicate each CCD's 7 vCPU cores to its VM; leave each CCD's 8th
  # core (7,23 amd-emu/IO . 15,31 nvidia-emu/IO) for the emulators + thin iGPU host,
  # and route host IRQs there.
  boot.kernelParams = [
    "isolcpus=domain,managed_irq,0-6,8-14,16-22,24-30"
    "nohz_full=0-6,8-14,16-22,24-30"
    "rcu_nocbs=0-6,8-14,16-22,24-30"
    "irqaffinity=7,15,23,31"
  ];

  # -- USB: amd VM gets the full host control surface (headless host, no mixing) --
  # GoXLR + Stream Deck + keyboard + mouse + Bluetooth all move INTO the amd VM
  # (you control audio in-VM); the SupremeFX stays with the nvidia VM (its base
  # usbPassthrough -- the 2nd person's sound card). Decimal vendor:product per
  # NixVirt's int schema, verified against lsusb on this host.
  myModules.vfio.vms.win11-amd.usbPassthrough = lib.mkForce [
    {
      vendorId = 4640; # 0x1220 TC-Helicon
      productId = 36836; # 0x8fe4 GoXLR Mini
    }
    {
      vendorId = 4057; # 0x0fd9 Elgato
      productId = 109; # 0x006d Stream Deck
    }
    {
      vendorId = 12851; # 0x3233 Ducky
      productId = 29; # 0x001d One X Mini keyboard
    }
    {
      vendorId = 1133; # 0x046d Logitech
      productId = 50489; # 0xc539 Lightspeed receiver (mouse)
    }
    {
      vendorId = 1161; # 0x0489 Foxconn
      productId = 57628; # 0xe11c Bluetooth
    }
  ];

  # -- Don't auto-mount the amd VM's NVMe (R6) --
  # /mnt/Windows-SSD (0f) is the amd VM's passed disk; its x-systemd.automount can
  # re-grab 0f racing the autostart VM. noauto stops the host claiming it (the VM
  # owns 0f at boot). nvidia's 0b has no host fileSystems entry -- nothing to gate.
  fileSystems."/mnt/Windows-SSD".options = lib.mkForce [
    "uid=1000"
    "gid=100"
    "dmask=022"
    "fmask=133"
    "noexec"
    "nosuid"
    "nodev"
    "nofail"
    "noauto"
  ];

  # -- Thin-host service audit -- explicit mkForce false per line, no aggregate --
  # KEPT (essential to the hypervisor host, NOT listed here): sshd + fail2ban,
  # libvirtd (+virtlogd, default-network, libvirt-guests), NetworkManager, acpid +
  # logind, CoolerControl + nct6799 + zenpower (THERMAL-CRITICAL), the iGPU amdgpu,
  # earlyoom, agenix, avahi (so `ssh ryzen.local` still resolves -- R4).
  myModules.services.cups.enable = lib.mkForce false; # no printing on a VM host
  security.rtkit.enable = lib.mkForce false; # set unconditionally in hardening.nix; pipewire-off doesn't cascade it, and there's no host audio in this headless profile
  myModules.hardware.upower.enable = lib.mkForce false; # desktop battery/power UI, pointless here
  myModules.hardware.usbmuxd.enable = lib.mkForce false; # iOS USB muxing, pointless here
  myModules.services.geoclue.enable = lib.mkForce false; # location service, no desktop apps
  myModules.desktop.flatpak.enable = lib.mkForce false; # no desktop apps on a thin host
  myModules.hardware.bluetooth.enable = lib.mkForce false; # the BT adapter is USB-passed to the amd VM
  services.fwupd.enable = lib.mkForce false; # firmware updater, irrelevant on a VM host (hardware.core keeps microcode)
  systemd.services.ModemManager.enable = lib.mkForce false; # no cellular modem
  services.udisks2.enable = lib.mkForce false; # removable-media automount, no desktop session
  # Passed-device / host-only daemons whose device or purpose is gone:
  myModules.hardware.gpuAmd.lact.enable = lib.mkForce false; # 9070 XT is passed -> no host undervolt
  myModules.hardware.goxlr.utility.enable = lib.mkForce false; # GoXLR is USB-passed to the amd VM
  myModules.input.streamcontroller.enable = lib.mkForce false; # Stream Deck is USB-passed to the amd VM
  myModules.input.ratbagd.enable = lib.mkForce false; # the mouse is USB-passed to the amd VM
  myModules.input.yeetmouse.enable = lib.mkForce false; # mouse passed -> in-VM Raw Accel handles accel
  myModules.tuning.corecycler.enable = lib.mkForce false; # CPU diagnostics, irrelevant while both CCDs run VMs
  myModules.hardware.udevAccess.enable = lib.mkForce false; # dev-probe udev rules, not needed on a VM host
  # No host audio on the headless host (pipewire stack would idle pointlessly):
  myModules.hardware.pipewire.enable = lib.mkForce false; # no host audio (VMs own their own audio devices)
  # Gaming stack -- you game INSIDE the VMs, not on the host:
  myModules.gaming.steam.enable = lib.mkForce false;
  myModules.gaming.gamescope.enable = lib.mkForce false;
  myModules.gaming.gamemode.enable = lib.mkForce false;
  myModules.gaming.rocksmith.enable = lib.mkForce false;
  # VPN/firewall OFF here: the VMs are bridged onto br0 with bridge-nf-call=0, so
  # their traffic bypasses host netfilter regardless, and a headless host has
  # nothing of its own to tunnel/filter.
  myModules.services.mullvad.enable = lib.mkForce false;
  myModules.security.portmaster.enable = lib.mkForce false;
  myModules.security.portmasterMullvadCompat.enable = lib.mkForce false; # glue is moot with both off
  myModules.security.portmasterSplitTunnelCompat.enable = lib.mkForce false; # same: no Portmaster to exempt from
}
