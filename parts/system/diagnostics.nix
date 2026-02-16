{ inputs, ... }: {
  flake.nixosModules.system-diagnostics = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.diagnostics;
    in {
      options.myModules.system.diagnostics.enable = lib.mkEnableOption "System diagnostics command (sysdiag)";
      
      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          (pkgs.writeShellScriptBin "sysdiag" ''
            #!/usr/bin/env bash
            RED='\033[0;31m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            BLUE='\033[0;34m'
            NC='\033[0m'
            BOLD='\033[1m'

            header() { echo -e "\n''${BLUE}=== $1 ===''${NC}"; }
            item() { echo -e "  ''${BOLD}$1:''${NC} $2"; }
            
            show_help() {
              echo "Usage: sysdiag [option]"
              echo "Options:"
              echo "  --cpu       CPU information"
              echo "  --gpu       GPU information"
              echo "  --memory    Memory usage"
              echo "  --disk      Disk usage and health"
              echo "  --network   Network interfaces and status"
              echo "  --all       Run all diagnostics"
              echo "  --help      Show this help"
            }

            cpu_info() {
              header "CPU Information"
              ${pkgs.fastfetch}/bin/fastfetch --structure CPU --stateless
              echo ""
              ${pkgs.util-linux}/bin/lscpu | grep "Model name" | sed 's/Model name:[ \t]*//'
              sensors | grep "Core 0" || echo "Temp: N/A"
            }

            gpu_info() {
              header "GPU Information"
              ${pkgs.pciutils}/bin/lspci | grep -i vga
              if command -v nvidia-smi &> /dev/null; then nvidia-smi; fi
              if command -v radeontop &> /dev/null; then echo "Radeontop available (run separately)"; fi
              glxinfo | grep "OpenGL renderer" || echo "OpenGL: N/A"
              vulkaninfo --summary 2>/dev/null | grep "deviceName" || echo "Vulkan: N/A"
            }

            mem_info() {
              header "Memory Information"
              free -h
            }

            disk_info() {
              header "Disk Information"
              df -h / /home /boot
              echo ""
              lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v loop
            }

            net_info() {
              header "Network Information"
              ip -c a
              echo ""
              ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo -e "Internet: ''${GREEN}Connected''${NC}" || echo -e "Internet: ''${RED}Disconnected''${NC}"
            }

            case "$1" in
              --cpu) cpu_info ;;
              --gpu) gpu_info ;;
              --memory) mem_info ;;
              --disk) disk_info ;;
              --network) net_info ;;
              --all|*) 
                ${pkgs.fastfetch}/bin/fastfetch
                cpu_info
                gpu_info
                mem_info
                disk_info
                net_info
                ;;
            esac
          '')
          pkgs.pciutils pkgs.usbutils pkgs.lm_sensors pkgs.smartmontools
          pkgs.vulkan-tools pkgs.mesa-demos
          pkgs.fastfetch pkgs.util-linux pkgs.iproute2 pkgs.ethtool
          pkgs.wlr-randr pkgs.kdePackages.libkscreen pkgs.upower
        ];
      };
    };
}
