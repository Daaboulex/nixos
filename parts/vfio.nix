{ inputs, ... }:
{
  flake.nixosModules.vfio =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.vfio;
      user = config.myModules.primaryUser;

      # Parse PCI address string "0000:03:00.0" into integers for NixVirt
      # Nix has no hex parsing, so we convert manually
      hexToInt =
        s:
        let
          hexChars = {
            "0" = 0;
            "1" = 1;
            "2" = 2;
            "3" = 3;
            "4" = 4;
            "5" = 5;
            "6" = 6;
            "7" = 7;
            "8" = 8;
            "9" = 9;
            "a" = 10;
            "b" = 11;
            "c" = 12;
            "d" = 13;
            "e" = 14;
            "f" = 15;
            "A" = 10;
            "B" = 11;
            "C" = 12;
            "D" = 13;
            "E" = 14;
            "F" = 15;
          };
          chars = lib.stringToCharacters s;
        in
        lib.foldl (acc: c: acc * 16 + hexChars.${c}) 0 chars;

      parsePciAddr =
        addr:
        let
          parts = builtins.match "([0-9a-fA-F]+):([0-9a-fA-F]+):([0-9a-fA-F]+)\\.([0-9]+)" addr;
        in
        {
          type = "pci";
          domain = 0;
          bus = hexToInt (builtins.elemAt parts 1);
          slot = hexToInt (builtins.elemAt parts 2);
          function = lib.toInt (builtins.elemAt parts 3);
        };

      # Generate MAC address from prefix + VM name hash
      generateMac =
        prefix: name:
        let
          hash = builtins.hashString "sha256" name;
          hexChars = lib.stringToCharacters hash;
          b1 = lib.concatStrings (lib.sublist 0 2 hexChars);
          b2 = lib.concatStrings (lib.sublist 2 2 hexChars);
          b3 = lib.concatStrings (lib.sublist 4 2 hexChars);
        in
        "${prefix}:${b1}:${b2}:${b3}";

      # Dynamic VFIO bind/unbind hook script
      enabledVms = lib.filterAttrs (_: v: v.enable) cfg.vms;

      # Collect all GPU PCI addresses from VMs that use passthrough
      # Used for: hook script (bind/unbind), static binding (vfio-pci.ids)

      # Collect all PCI passthrough addresses (NVMe, USB controllers, etc.)

      # Per-VM hook: bind/unbind only the devices that specific VM uses
      mkVmHookSection =
        name: vmCfg:
        let
          gpuAddrs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [ vmCfg.gpu.pciAddress ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
          );
          nvmeAddrs = vmCfg.pciPassthrough;
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            ${lib.optionalString (nvmeAddrs != [ ]) ''
              # Unmount NVMe partitions before passthrough
              for pci_addr in ${lib.concatStringsSep " " nvmeAddrs}; do
                for nvme_dev in /sys/bus/pci/devices/$pci_addr/nvme/nvme*/nvme*n*; do
                  if [ -e "$nvme_dev" ]; then
                    blk_dev="/dev/$(basename "$nvme_dev")"
                    echo "VFIO [$GUEST_NAME]: unmounting partitions on $blk_dev"
                    for part in ''${blk_dev}p*; do
                      ${pkgs.util-linux}/bin/umount "$part" 2>/dev/null || true
                    done
                    ${pkgs.util-linux}/bin/umount "$blk_dev" 2>/dev/null || true
                  fi
                done
              done
            ''}
            ${lib.optionalString (gpuAddrs != [ ]) ''
              # Unbind GPU from host driver, bind to vfio-pci
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                  echo "VFIO [$GUEST_NAME]: unbinding $pci_addr from host driver"
                  if [ -f "/sys/bus/pci/devices/$pci_addr/driver/unbind" ]; then
                    echo "$pci_addr" > "/sys/bus/pci/devices/$pci_addr/driver/unbind" 2>/dev/null || true
                  fi
                  echo "vfio-pci" > "/sys/bus/pci/devices/$pci_addr/driver_override"
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
                fi
              done
            ''}
          fi
        '';

      mkVmReleaseSection =
        name: vmCfg:
        let
          gpuAddrs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [ vmCfg.gpu.pciAddress ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
          );
        in
        lib.optionalString (gpuAddrs != [ ]) ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            # Unbind from vfio-pci, clear override
            for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
              if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                echo "VFIO [$GUEST_NAME]: unbinding $pci_addr from vfio-pci"
                echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
                echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override"
              fi
            done
            echo "VFIO [$GUEST_NAME]: rescanning PCI bus"
            echo 1 > /sys/bus/pci/rescan
          fi
        '';

      vfioHookScript = pkgs.writeShellScript "qemu-hook" ''
        GUEST_NAME="$1"
        HOOK_NAME="$2"
        STATE_NAME="$3"

        if [ "$HOOK_NAME" = "prepare" ] && [ "$STATE_NAME" = "begin" ]; then
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkVmHookSection enabledVms)}
        fi

        if [ "$HOOK_NAME" = "release" ] && [ "$STATE_NAME" = "end" ]; then
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkVmReleaseSection enabledVms)}
        fi
      '';

      # Per-VM submodule type
      vmSubmodule = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to define this VM";
          };
          uuid = lib.mkOption {
            type = lib.types.str;
            description = "Libvirt domain UUID (generate with `uuidgen`)";
          };
          memory = {
            count = lib.mkOption {
              type = lib.types.int;
              default = 16;
              description = "RAM allocation in GiB";
            };
          };
          vcpu = {
            count = lib.mkOption {
              type = lib.types.int;
              default = 16;
              description = "Number of virtual CPUs";
            };
            pinning = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.int);
              default = null;
              description = "List of host CPU cores to pin vCPUs to (null = no pinning)";
            };
          };
          os = {
            firmware = lib.mkOption {
              type = lib.types.enum [
                "uefi"
                "bios"
              ];
              default = "uefi";
              description = "Firmware type";
            };
            tpm = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Emulated TPM 2.0 via swtpm";
            };
          };
          disk = {
            path = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to qcow2/raw disk image (null = no virtual disk, use PCI passthrough instead)";
            };
            format = lib.mkOption {
              type = lib.types.enum [
                "qcow2"
                "raw"
              ];
              default = "raw";
              description = "Disk image format (raw for best performance)";
            };
            bus = lib.mkOption {
              type = lib.types.enum [
                "virtio"
                "sata"
                "scsi"
              ];
              default = "virtio";
              description = "Disk bus type";
            };
          };
          iso = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to install ISO (null = no CD-ROM)";
          };
          gpu = {
            mode = lib.mkOption {
              type = lib.types.enum [
                "passthrough"
                "emulated"
              ];
              default = "passthrough";
              description = "GPU mode: passthrough = dGPU via VFIO (production); emulated = QXL/SPICE in virt-manager (testing)";
            };
            pciAddress = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "GPU PCI address (e.g. '0000:03:00.0')";
            };
            audioAddress = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "GPU audio function PCI address (e.g. '0000:03:00.1')";
            };
            romFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to GPU VBIOS ROM file (null = no ROM override)";
            };
          };
          network = {
            type = lib.mkOption {
              type = lib.types.enum [
                "nat"
                "bridge"
              ];
              default = "nat";
              description = "Network type";
            };
            bridge = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Bridge name (required if type = bridge)";
            };
            mac = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "MAC address (null = auto-generated from stealth prefix + VM name)";
            };
          };
          pciPassthrough = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional PCI addresses to pass through (e.g. NVMe controllers, USB controllers)";
            example = [
              "0000:05:00.0"
            ];
          };
          # CPU identity spoofing (per-VM — different VMs on different CCDs can spoof different CPUs)
          cpuIdentity = {
            modelId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "CPUID brand string override (null = use real host CPU name). E.g. 'AMD Ryzen 7 9850X3D 8-Core Processor' for CCD0 V-Cache, 'AMD Ryzen 7 9700X 8-Core Processor' for CCD1";
              example = "AMD Ryzen 7 9850X3D 8-Core Processor";
            };
            maxSpeed = lib.mkOption {
              type = lib.types.int;
              default = 5600;
              description = "SMBIOS Type 4 max speed in MHz (boost clock of spoofed CPU)";
            };
            currentSpeed = lib.mkOption {
              type = lib.types.int;
              default = 4700;
              description = "SMBIOS Type 4 current speed in MHz (base clock of spoofed CPU)";
            };
          };
          extraQemuArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra QEMU command-line arguments";
          };
        };
      };

      # Build NixVirt domain definition for a VM
      mkDomainDef =
        name: vmCfg:
        let
          mac =
            if vmCfg.network.mac != null then
              vmCfg.network.mac
            else if cfg.stealth.spoofMac then
              generateMac cfg.stealth.macPrefix name
            else
              null;

          cpuPinning =
            if vmCfg.vcpu.pinning != null then
              {
                vcpupin = lib.imap0 (i: core: {
                  vcpu = i;
                  cpuset = toString core;
                }) vmCfg.vcpu.pinning;
                # Pin emulator threads to host CCD (avoid stealing VM cores)
                # Use cores 8-9 (CCD1 physical cores) for emulator overhead
                emulatorpin.cpuset = "8-9";
                # Pin IO thread to a dedicated host core
                iothreadpin = [
                  {
                    iothread = 1;
                    cpuset = "10";
                  }
                ];
              }
            else
              null;

          gpuHostdevs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [
              {
                mode = "subsystem";
                type = "pci";
                managed = true;
                source.address = parsePciAddr vmCfg.gpu.pciAddress;
                rom = {
                  bar = true;
                }
                // lib.optionalAttrs (vmCfg.gpu.romFile != null) { file = vmCfg.gpu.romFile; };
              }
            ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [
              {
                mode = "subsystem";
                type = "pci";
                managed = true;
                source.address = parsePciAddr vmCfg.gpu.audioAddress;
              }
            ]
          );

          # Extra PCI passthrough devices (NVMe, USB controllers, etc.)
          extraPciHostdevs = lib.map (addr: {
            mode = "subsystem";
            type = "pci";
            managed = true;
            source.address = parsePciAddr addr;
          }) vmCfg.pciPassthrough;
        in
        {
          type = "kvm";
          inherit name;
          inherit (vmCfg) uuid;

          memory = {
            inherit (vmCfg.memory) count;
            unit = "GiB";
          };
          currentMemory = {
            inherit (vmCfg.memory) count;
            unit = "GiB";
          };

          vcpu = {
            placement = "static";
            inherit (vmCfg.vcpu) count;
          };

          cputune = cpuPinning;
          iothreads.count = 1;

          # SMBIOS injection via sysinfo (stealth)
          sysinfo =
            if cfg.stealth.enable then
              {
                type = "smbios";
                bios.entry = [
                  {
                    name = "vendor";
                    value = cfg.stealth.smbios.biosVendor;
                  }
                  {
                    name = "version";
                    value = cfg.stealth.smbios.biosVersion;
                  }
                ];
                system.entry = [
                  {
                    name = "manufacturer";
                    value = cfg.stealth.smbios.manufacturer;
                  }
                  {
                    name = "product";
                    value = cfg.stealth.smbios.product;
                  }
                  {
                    name = "serial";
                    value = cfg.stealth.smbios.serial;
                  }
                  {
                    name = "uuid";
                    value = vmCfg.uuid;
                  }
                  {
                    name = "family";
                    value = "To be filled by O.E.M.";
                  }
                ];
                baseBoard.entry = [
                  {
                    name = "manufacturer";
                    value = cfg.stealth.smbios.manufacturer;
                  }
                  {
                    name = "product";
                    value = cfg.stealth.smbios.product;
                  }
                ];
              }
            else
              null;

          os = {
            type = "hvm";
            arch = "x86_64";
            machine = "pc-q35-10.0";
            smbios.mode = if cfg.stealth.enable then "sysinfo" else null;
            boot = [ { dev = "hd"; } ] ++ lib.optionals (vmCfg.iso != null) [ { dev = "cdrom"; } ];
          };

          cpu = {
            mode = "host-passthrough";
            check = "none";
            migratable = false;
            topology = {
              sockets = 1;
              dies = 1;
              cores = vmCfg.vcpu.count / 2;
              threads = 2;
            };
            cache.mode = "passthrough";
            feature =
              (lib.optionals cfg.stealth.enable [
                {
                  policy = "disable";
                  name = "hypervisor";
                }
              ])
              ++ [
                {
                  policy = "require";
                  name = "topoext";
                }
                {
                  policy = "require";
                  name = "invtsc";
                }
              ];
          };

          features = {
            acpi = { };
            apic = { };
            ioapic.driver = "kvm";
            smm.state = true;
          }
          // lib.optionalAttrs cfg.stealth.enable {
            hyperv = {
              mode = "custom";
              relaxed.state = true;
              vapic.state = true;
              spinlocks = {
                state = true;
                retries = 8191;
              };
              vpindex.state = true;
              runtime.state = true;
              synic.state = true;
              stimer = {
                state = true;
                direct.state = true;
              };
              reset.state = true;
              vendor_id = {
                state = true;
                value = "AMDisbetter!";
              };
              frequencies.state = true;
              reenlightenment.state = true;
              tlbflush.state = true;
              ipi.state = true;
            };
            kvm = {
              hidden.state = true;
              hint-dedicated.state = true;
              poll-control.state = true;
            };
            vmport.state = false;
          };

          clock = {
            offset = "localtime";
            timer = [
              {
                name = "rtc";
                tickpolicy = "catchup";
              }
              {
                name = "pit";
                tickpolicy = "delay";
              }
              {
                name = "hpet";
                present = false;
              }
              {
                name = "kvmclock";
                present = false;
              }
              {
                name = "hypervclock";
                present = true;
              }
              {
                name = "tsc";
                present = true;
                mode = "native";
              }
            ];
          };

          on_poweroff = "destroy";
          on_reboot = "restart";
          on_crash = "destroy";

          memoryBacking =
            if (cfg.hugepages.enable || cfg.lookingGlass.enable) then
              {
                source.type = "memfd";
                access.mode = "shared";
              }
              // lib.optionalAttrs cfg.hugepages.enable {
                hugepages =
                  { }
                  // lib.optionalAttrs (cfg.hugepages.size == "1G") {
                    page = [
                      {
                        size = 1;
                        unit = "GiB";
                      }
                    ];
                  };
                nosharepages = { };
                locked = { };
              }
            else
              null;

          devices = {
            emulator = "${if cfg.stealth.enable then pkgs.qemu-stealth else pkgs.qemu}/bin/qemu-system-x86_64";

            disk =
              lib.optionals (vmCfg.disk.path != null) [
                {
                  type = "file";
                  device = "disk";
                  driver = {
                    name = "qemu";
                    type = vmCfg.disk.format;
                    cache = "none";
                    io = "native";
                    discard = "unmap";
                  };
                  source.file = vmCfg.disk.path;
                  target = {
                    dev = "vda";
                    inherit (vmCfg.disk) bus;
                  };
                  boot.order = 1;
                }
              ]
              ++ lib.optionals (vmCfg.iso != null) [
                {
                  type = "file";
                  device = "cdrom";
                  driver = {
                    name = "qemu";
                    type = "raw";
                  };
                  source.file = vmCfg.iso;
                  target = {
                    dev = "sda";
                    bus = "sata";
                  };
                  readonly = true;
                  boot.order = 2;
                }
              ];

            hostdev = gpuHostdevs ++ extraPciHostdevs;

            # Looking Glass shared memory
            shmem = lib.optionals cfg.lookingGlass.enable [
              {
                name = "looking-glass";
                model.type = "ivshmem-plain";
                size = {
                  unit = "M";
                  count = cfg.lookingGlass.memoryMB;
                };
              }
            ];

            controller = [
              {
                type = "pci";
                index = 0;
                model = "pcie-root";
              }
              {
                type = "pci";
                index = 1;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 2;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 3;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 4;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 5;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 6;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 7;
                model = "pcie-root-port";
              }
              {
                type = "usb";
                index = 0;
                model = "qemu-xhci";
              }
              {
                type = "scsi";
                index = 0;
                model = "virtio-scsi";
              }
            ];

            interface =
              (
                if vmCfg.network.type == "nat" then
                  {
                    type = "network";
                    source.network = "default";
                    model.type = "e1000e";
                  }
                else
                  {
                    type = "bridge";
                    source.bridge = vmCfg.network.bridge;
                    model.type = "e1000e";
                  }
              )
              // lib.optionalAttrs (mac != null) { mac.address = mac; };

            input = [
              {
                type = "mouse";
                bus = "virtio";
              }
              {
                type = "keyboard";
                bus = "virtio";
              }
            ];

            # Emulated video + SPICE when not using GPU passthrough (for virt-manager display)
            video = lib.optionals (vmCfg.gpu.mode == "emulated") [
              {
                model = {
                  type = "qxl";
                  ram = 65536;
                  vram = 65536;
                  vgamem = 16384;
                };
              }
            ];
            graphics = lib.optionals (vmCfg.gpu.mode == "emulated") [
              {
                type = "spice";
                autoport = true;
                listen.type = "address";
              }
            ];
            # Audio for SPICE when not using GPU passthrough
            sound = lib.optionals (vmCfg.gpu.mode == "emulated") [
              { model = "ich9"; }
            ];
            channel = lib.optionals (vmCfg.gpu.mode == "emulated") [
              {
                type = "spicevmc";
                target = {
                  type = "virtio";
                  name = "com.redhat.spice.0";
                };
              }
            ];

            memballoon.model = "none";
          };

          # QEMU command-line passthrough for stealth args and evdev
          qemu-commandline = {
            arg =
              # CPUID brand string override — guest sees spoofed CPU model in /proc/cpuinfo
              (lib.optionals (cfg.stealth.enable && vmCfg.cpuIdentity.modelId != null) [
                { value = "-global"; }
                { value = "cpu.model-id=${vmCfg.cpuIdentity.modelId}"; }
              ])
              # SMBIOS type 4 (processor) — matches spoofed CPU in dmidecode
              ++ (lib.optionals (cfg.stealth.enable && vmCfg.cpuIdentity.modelId != null) [
                { value = "-smbios"; }
                {
                  value = "type=4,sock_pfx=AM5,manufacturer=Advanced Micro Devices\\, Inc.,version=${vmCfg.cpuIdentity.modelId},max-speed=${toString vmCfg.cpuIdentity.maxSpeed},current-speed=${toString vmCfg.cpuIdentity.currentSpeed}";
                }
              ])
              # SMBIOS type 3 (chassis) — prevents empty WMI Win32_SystemEnclosure
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-smbios"; }
                {
                  value = "type=3,manufacturer=${cfg.stealth.smbios.manufacturer},version=1.0,serial=Default string,asset=Default string,sku=Default string";
                }
              ])
              # SMBIOS type 27 (cooling device) — prevents empty WMI Win32_Fan (2025 detection vector)
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-smbios"; }
                { value = "type=27,type=32,status=3,speed=3200"; }
              ])
              # SMBIOS type 28 (temperature probe) — prevents empty WMI Win32_TemperatureProbe
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-smbios"; }
                { value = "type=28,description=CPU Thermal Probe,type=3,status=3,max=1000,min=100"; }
              ])
              # CPU power management hint (stealth)
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-overcommit"; }
                { value = "cpu-pm=on"; }
              ])
              # Evdev input passthrough
              ++ (lib.optionals (cfg.evdev.enable && cfg.evdev.keyboardPath != null) [
                { value = "-object"; }
                {
                  value = "input-linux,id=kbd,evdev=${cfg.evdev.keyboardPath},grab_all=on,repeat=on";
                }
              ])
              ++ (lib.optionals (cfg.evdev.enable && cfg.evdev.mousePath != null) [
                { value = "-object"; }
                { value = "input-linux,id=mouse,evdev=${cfg.evdev.mousePath}"; }
              ])
              ++ (lib.map (a: { value = a; }) vmCfg.extraQemuArgs);
          };
        };

    in
    {
      _class = "nixos";

      # ========================================================================
      # Options
      # ========================================================================
      options.myModules.vfio = {
        enable = lib.mkEnableOption "VFIO GPU passthrough with stealth VM management";

        # --- VFIO Device Binding ---
        bindMethod = lib.mkOption {
          type = lib.types.enum [
            "static"
            "dynamic"
          ];
          default = "dynamic";
          description = "static = vfio-pci.ids kernel param (GPU always captured at boot); dynamic = libvirt hooks bind/unbind on VM start/stop";
        };

        # PCI vendor:device IDs for static VFIO binding (only needed when bindMethod = static)
        # Dynamic binding uses PCI addresses from per-VM gpu config instead
        staticPciIds = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "PCI vendor:device IDs for static vfio-pci binding (e.g. [\"1002:7550\" \"1002:ab40\"])";
        };

        # --- Stealth ---
        stealth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Build patched QEMU with anti-detection + KVM kernel patches for RDTSC spoofing";
          };
          smbios = {
            manufacturer = lib.mkOption {
              type = lib.types.str;
              default = "ASUSTeK COMPUTER INC.";
              description = "SMBIOS system manufacturer";
            };
            product = lib.mkOption {
              type = lib.types.str;
              default = "ROG CROSSHAIR X870E HERO";
              description = "SMBIOS product name";
            };
            biosVendor = lib.mkOption {
              type = lib.types.str;
              default = "American Megatrends Inc.";
              description = "SMBIOS BIOS vendor";
            };
            biosVersion = lib.mkOption {
              type = lib.types.str;
              default = "2101";
              description = "SMBIOS BIOS version";
            };
            serial = lib.mkOption {
              type = lib.types.str;
              default = "System Serial Number";
              description = "SMBIOS system serial number";
            };
          };
          spoofMac = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Generate realistic MAC addresses with a real vendor OUI prefix";
          };
          macPrefix = lib.mkOption {
            type = lib.types.str;
            default = "04:42:1a";
            description = "MAC address OUI prefix (default: ASUS)";
          };
        };

        # --- Looking Glass ---
        lookingGlass = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "KVMFR shared memory for Looking Glass frame relay";
          };
          memoryMB = lib.mkOption {
            type = lib.types.int;
            default = 64;
            description = "KVMFR shared memory size in MB (32=1440p SDR, 64=4K SDR, 128=4K HDR)";
          };
        };

        # --- Evdev Input ---
        evdev = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Evdev input passthrough for keyboard/mouse";
          };
          keyboardPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to keyboard event device (e.g. /dev/input/by-id/...)";
          };
          mousePath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to mouse event device (e.g. /dev/input/by-id/...)";
          };
        };

        # --- Hugepages ---
        hugepages = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Static hugepage allocation for VM memory";
          };
          count = lib.mkOption {
            type = lib.types.int;
            default = 8192;
            description = "Number of hugepages to allocate";
          };
          size = lib.mkOption {
            type = lib.types.enum [
              "2M"
              "1G"
            ];
            default = "2M";
            description = "Hugepage size (1G = fewer TLB misses, best for gaming VMs)";
          };
        };

        # --- VM Definitions ---
        vms = lib.mkOption {
          type = lib.types.lazyAttrsOf vmSubmodule;
          default = { };
          description = "Per-VM definitions";
        };
      };

      # ========================================================================
      # Config
      # ========================================================================
      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # ── Core VFIO kernel setup ──
          {
            boot.kernelModules = [
              "vfio"
              "vfio_iommu_type1"
              "vfio-pci"
            ];

            boot.kernelParams = [
              "video=efifb:off" # Prevent host claiming passthrough GPU framebuffer
              "pcie_aspm=off" # Disable ASPM for passthrough devices (stability)
            ]
            # Static binding: vfio-pci captures devices at boot
            ++ lib.optionals (cfg.bindMethod == "static" && cfg.staticPciIds != [ ]) [
              "vfio-pci.ids=${lib.concatStringsSep "," cfg.staticPciIds}"
            ];
          }

          # ── KVM kernel patches for RDTSC spoofing (stealth) ──
          (lib.mkIf cfg.stealth.enable {
            boot.kernelPatches = [
              {
                name = "kvm-anti-detection-svm";
                patch = "${inputs.hypervisor-phantom}/patches/Kernel/linux-6.18.8-svm.patch";
              }
            ];

            # Stealth kernel params (idle=poll removed: wastes 100-150W, max_cstate=1 is sufficient on Zen 5)
            boot.kernelParams = [
              "processor.max_cstate=1" # Limit C-states to C1 (~1us wake, good stealth/power trade-off)
            ];
          })

          # ── Libvirt + QEMU ──
          {
            virtualisation.libvirtd = {
              enable = true;
              qemu = {
                package = if cfg.stealth.enable then pkgs.qemu-stealth else pkgs.qemu;
                runAsRoot = true;
                swtpm.enable = true;
                verbatimConfig = ''
                  cgroup_device_acl = [
                    "/dev/null", "/dev/full", "/dev/zero",
                    "/dev/random", "/dev/urandom",
                    "/dev/ptmx", "/dev/kvm",
                    "/dev/kvmfr0",
                    "/dev/vfio/vfio"
                  ]
                '';
              };
            };

            # User access to libvirt and KVM
            users.users.${user}.extraGroups = [
              "libvirtd"
              "kvm"
              "input"
            ];

            # Virsh and virt-manager
            environment.systemPackages = with pkgs; [
              virt-manager
              virt-viewer
            ];

            # virt-manager auto-connects to local QEMU/KVM
            programs.virt-manager.enable = true;
            # dconf settings for virt-manager (auto-connect, console settings)
            programs.dconf.enable = true;

            # Default NAT network
            networking.firewall.trustedInterfaces = [ "virbr0" ];

            # Never auto-start or auto-resume VMs — only manual launch via virt-manager
            systemd.services.libvirt-guests.serviceConfig = {
              ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
            };

            # Ensure autostart is disabled for all defined VMs after NixVirt defines them
            systemd.services.vfio-disable-autostart = {
              description = "Disable libvirt VM autostart";
              after = [
                "libvirtd.service"
                "nixvirt.service"
              ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = lib.concatMapStringsSep "\n" (name: ''
                ${pkgs.libvirt}/bin/virsh autostart --disable ${name} 2>/dev/null || true
              '') (lib.attrNames enabledVms);
            };
          }

          # ── NixVirt declarative VM definitions ──
          (lib.mkIf (enabledVms != { }) {
            virtualisation.libvirt = {
              enable = true;
              swtpm.enable = true;
              connections."qemu:///system".domains = lib.mapAttrsToList (name: vmCfg: {
                definition = inputs.NixVirt.lib.domain.writeXML (mkDomainDef name vmCfg);
                active = null;
              }) enabledVms;
            };
          })

          # ── Dynamic VFIO hook ──
          (lib.mkIf (cfg.bindMethod == "dynamic") {
            systemd.tmpfiles.rules = [
              "d /var/lib/libvirt/hooks 0755 root root -"
            ];

            environment.etc."libvirt/hooks/qemu" = {
              source = vfioHookScript;
              mode = "0755";
            };
          })

          # ── Looking Glass ──
          (lib.mkIf cfg.lookingGlass.enable {
            boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
            boot.kernelModules = [ "kvmfr" ];
            boot.extraModprobeConfig = ''
              options kvmfr static_size_mb=${toString cfg.lookingGlass.memoryMB}
            '';

            services.udev.extraRules = ''
              SUBSYSTEM=="kvmfr", OWNER="${user}", GROUP="kvm", MODE="0660"
            '';

            environment.systemPackages = [ pkgs.looking-glass-client ];
          })

          # ── Evdev input permissions ──
          (lib.mkIf cfg.evdev.enable {
            services.udev.extraRules = ''
              SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="input"
            '';
          })

          # ── Hugepages ──
          (lib.mkIf cfg.hugepages.enable {
            boot.kernelParams = [
              "default_hugepagesz=${cfg.hugepages.size}"
              "hugepagesz=${cfg.hugepages.size}"
              "hugepages=${toString cfg.hugepages.count}"
            ];
          })

          # ── VM disk directory ──
          {
            systemd.tmpfiles.rules = [
              "d /var/lib/vfio 0770 ${user} libvirtd -"
            ];
          }
        ]
      );
    };
}
