{ inputs, ... }: {
  flake.nixosModules.apps-tools = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.development.tools;
      cfgTools = config.myModules.tools;
      
      list-gpu-drivers = pkgs.writeShellApplication {
        name = "list-gpu-drivers";
        runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.pciutils pkgs.gnugrep pkgs.gawk pkgs.gnused pkgs.mesa-demos pkgs.vulkan-tools ];
        text = ''#!${pkgs.bash}/bin/bash
          set -euo pipefail
          echo "=== GPU Drivers & Status ==="
          echo ""
          echo "--- PCI Devices ---"
          lspci -nnk | grep -i vga -A3
          echo ""
          echo "--- OpenGL ---"
          glxinfo | grep "OpenGL renderer" || echo "OpenGL info not available"
          echo ""
          echo "--- Vulkan ---"
          vulkaninfo --summary 2>/dev/null | grep "deviceName" || echo "Vulkan info not available"
        '';
      };

      list-iommu-groups = pkgs.writeShellApplication {
        name = "list-iommu-groups";
        runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.pciutils ];
        text = ''#!${pkgs.bash}/bin/bash
          set -euo pipefail
          echo "=== IOMMU Groups ==="
          shopt -s nullglob
          for g in /sys/kernel/iommu_groups/*; do
            echo "Group $(basename "$g"):"
            for d in "$g"/devices/*; do
              echo -n "  "
              lspci -nns "$(basename "$d")"
            done
          done
        '';
      };
      
      llm-prep = pkgs.writeShellApplication {
        name = "llm-prep";
        runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.findutils pkgs.tree ];
        text = ''#!${pkgs.bash}/bin/bash
          # Combines project files into a single context for LLMs
          # Usage: llm-prep [directory] [-o output.txt]
          set -euo pipefail
          
          TARGET_DIR="''${1:-.}"
          OUTPUT_FILE="context.txt"
          
          if [[ "''${2:-}" == "-o" ]]; then
            OUTPUT_FILE="''${3:-context.txt}"
          fi

          echo "Generating context from $TARGET_DIR into $OUTPUT_FILE..."
          
          {
            echo "Project Structure:"
            ${pkgs.tree}/bin/tree "$TARGET_DIR" -I "result|node_modules|.git" --dirsfirst
            echo -e "\nFile Contents:\n"
            
            ${pkgs.findutils}/bin/find "$TARGET_DIR" -maxdepth 3 -type f \
              -not -path '*/.*' \
              -not -path '*/result/*' \
              -not -name "*.lock" \
              -not -name "*.png" \
              -not -name "*.jpg" \
              -print0 | while IFS= read -r -d "" file; do
                echo "=== $file ==="
                cat "$file"
                echo -e "\n"
            done
          } > "$OUTPUT_FILE"
          
          echo "Done: $OUTPUT_FILE"
        '';
      };
    in {
      options.myModules.development.tools = {
        enable = lib.mkEnableOption "Development Tools";
        helperScripts = lib.mkEnableOption "Enable helper scripts";
      };
      options.myModules.tools = {
         listGpuDrivers.enable = lib.mkEnableOption "list-gpu-drivers";
         listIommuGroups.enable = lib.mkEnableOption "list-iommu-groups";
         llmPrep.enable = lib.mkEnableOption "llm-prep";
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
           environment.systemPackages = with pkgs; [ vscodium google-antigravity direnv devenv nix-prefetch-git saleae-logic-2 gnumake cmake pkg-config gcc python3 nodejs ];
           services.udev.packages = [ pkgs.saleae-logic-2 ];
           services.udev.extraRules = ''
             SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", MODE="0666", GROUP="users"
             KERNEL=="hidraw*", ATTRS{idVendor}=="1fc9", MODE="0666", GROUP="users"
           '';
           # Enable helpers if requested
           myModules.tools.listGpuDrivers.enable = lib.mkIf cfg.helperScripts true;
           myModules.tools.listIommuGroups.enable = lib.mkIf cfg.helperScripts true;
           myModules.tools.llmPrep.enable = lib.mkIf cfg.helperScripts true;
        })
        
        (lib.mkIf cfgTools.listGpuDrivers.enable { environment.systemPackages = [ list-gpu-drivers ]; })
        (lib.mkIf cfgTools.listIommuGroups.enable { environment.systemPackages = [ list-iommu-groups ]; })
        (lib.mkIf cfgTools.llmPrep.enable { environment.systemPackages = [ llm-prep ]; })
      ];
    };
}
