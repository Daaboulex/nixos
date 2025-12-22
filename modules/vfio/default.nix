{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.libvirtVfioHooks;
  lspciPath = "${pkgs.pciutils}/bin/lspci";
  grepPath = "${pkgs.gnugrep}/bin/grep";
  awkPath = "${pkgs.gawk}/bin/awk";
  virshPath = "${pkgs.libvirt}/bin/virsh";
  modprobePath = "${pkgs.kmod}/bin/modprobe";
  echoPath = "${pkgs.coreutils}/bin/echo";
  catPath = "${pkgs.coreutils}/bin/cat";
  sleepPath = "${pkgs.coreutils}/bin/sleep";
  systemctlPath = "${pkgs.systemd}/bin/systemctl";
  lsmodPath = "${pkgs.procps}/bin/lsmod";
  mkHookScriptFile = name: scriptContent: pkgs.writeTextFile {
    name = "${name}.sh";
    text = ''
      #!${pkgs.runtimeShell}
      set -eu
      PATH=${lib.makeBinPath [ pkgs.libvirt pkgs.kmod pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.pciutils pkgs.systemd pkgs.procps ]}:$PATH
      ${echoPath} "Executing script: $(basename $0)"
      if [[ $# -gt 0 ]]; then ${echoPath} "VM: $1"; fi
      ${echoPath} "--- Starting script at $(date) ---"
      ${scriptContent}
      ${echoPath} "--- Finished script at $(date) ---"
      exit 0
    '';
    executable = true;
  };
  generateDetachLoop = devices: lib.concatMapStringsSep "\n" (pciId: ''
    ${echoPath} "  Detaching ${pciId}..."
    current_driver=$(${lspciPath} -k -s "''${pciId#pci_}" | ${grepPath} 'Kernel driver in use:' | ${awkPath} '{print $NF}' || ${echoPath} "none")
    ${echoPath} "    Current driver: $current_driver"
    if [ "''$current_driver" = "vfio-pci" ]; then
      ${echoPath} "    Already bound to vfio, skipping detach."
    elif [ "''$current_driver" = "none" ]; then
      ${echoPath} "    Not bound to any known driver, skipping detach."
    else
      ${virshPath} nodedev-detach ${pciId} || ${echoPath} "    [WARN] Failed to detach ${pciId} from ''$current_driver."
    fi
  '') devices;
  generateReattachLoop = devices: lib.concatMapStringsSep "\n" (pciId: ''
    ${echoPath} "  Reattaching ${pciId}..."
    ${virshPath} nodedev-reattach ${pciId} || {
        ${echoPath} "    [WARN] Failed reattach ${pciId}"
        all_reattach_successful=false
    }
    ${sleepPath} 0.1
  '') devices;
  bindHookScriptContent = ''
    ${echoPath} "[INFO] Setting CPU governor to performance..."
    BEFORE_GOVERNOR=$(${catPath} /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor || ${echoPath} "unknown")
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$file" ]; then ${echoPath} "performance" > "$file" || ${echoPath} "[WARN] Failed set performance for $file"; fi; done
    ${lib.optionalString (cfg.memoryMb > 0) ''
      ${echoPath} "[INFO] Allocating Hugepages..."
      MEMORY_MB=${toString cfg.memoryMb}; PAGE_SIZE_KB=$(${grepPath} Hugepagesize /proc/meminfo | ${awkPath} '{print $2}'); if [ -z "$PAGE_SIZE_KB" ]; then ${echoPath} "[ERROR] No Hugepagesize"; exit 1; fi
      HUGEPAGES_TO_ALLOC=$(( MEMORY_MB * 1024 / PAGE_SIZE_KB )); ORIG_HP=$(${catPath} /proc/sys/vm/nr_hugepages)
      ${echoPath} $HUGEPAGES_TO_ALLOC > /proc/sys/vm/nr_hugepages; ALLOC_PAGES=$(${catPath} /proc/sys/vm/nr_hugepages); TRIES=0
      while (( ALLOC_PAGES < HUGEPAGES_TO_ALLOC && TRIES < 5 )); do ${echoPath} 1 > /proc/sys/vm/compact_memory; ${sleepPath} 1; ${echoPath} $HUGEPAGES_TO_ALLOC > /proc/sys/vm/nr_hugepages; ALLOC_PAGES=$(${catPath} /proc/sys/vm/nr_hugepages); let TRIES+=1; done
      if (( ALLOC_PAGES < HUGEPAGES_TO_ALLOC )); then ${echoPath} $ORIG_HP > /proc/sys/vm/nr_hugepages; exit 1; fi
    ''}
    ${modprobePath} vfio_pci || true
    ${modprobePath} vfio || true
    ${modprobePath} vfio_iommu_type1 || true
    ${generateDetachLoop cfg.devices}
  '';
  unbindHookScriptContent = ''
    ${lib.optionalString (cfg.memoryMb > 0) ''
      ORIG_HP=$(${catPath} /proc/sys/vm/nr_hugepages); ${echoPath} 0 > /proc/sys/vm/nr_hugepages
    ''}
    BEFORE_GOVERNOR=$(${catPath} /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor || ${echoPath} "unknown")
    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$file" ]; then ${echoPath} "${cfg.defaultGovernor}" > "$file" || ${echoPath} "[WARN] Failed set ${cfg.defaultGovernor}"; fi; done
    all_reattach_successful=true
    ${generateReattachLoop cfg.devices}
    ${sleepPath} 1
    if ${lsmodPath} | ${grepPath} -q '^nvidia\>'; then
      if ${systemctlPath} list-units --full --all | ${grepPath} -Fq 'nvidia-persistenced.service'; then if ! ${systemctlPath} is-active --quiet nvidia-persistenced.service; then ${systemctlPath} start nvidia-persistenced.service || true; fi; fi
    fi
    ${modprobePath} -r vfio_pci || true
    ${modprobePath} -r vfio_iommu_type1 || true
    ${modprobePath} -r vfio || true
  '';
  bindScriptFile = lib.mkIf (cfg.vmName != "") (mkHookScriptFile "bind-vfio-${cfg.vmName}" bindHookScriptContent);
  unbindScriptFile = lib.mkIf (cfg.vmName != "") (mkHookScriptFile "unbind-vfio-${cfg.vmName}" unbindHookScriptContent);
  dispatcherScriptFile = lib.mkIf (cfg.enable && cfg.vmName != "") (mkHookScriptFile "qemu-hook-dispatcher" ''
    #!${pkgs.runtimeShell}
    set -eu
    VM_NAME="$1"; OPERATION="$2"; SUB_OPERATION="$3"; LOCATION="$4"
    TARGET_VM_NAME="${cfg.vmName}"; HOOK_DIR="/etc/libvirt/hooks/qemu.d"; SCRIPT_PATH=""
    if [ "$VM_NAME" = "$TARGET_VM_NAME" ]; then
      if [ "$OPERATION" = "prepare" ] && [ "$LOCATION" = "begin" ]; then SCRIPT_PATH="$HOOK_DIR/$VM_NAME/prepare/begin/bind_vfio.sh";
      elif [ "$OPERATION" = "release" ] && [ "$LOCATION" = "end" ]; then SCRIPT_PATH="$HOOK_DIR/$VM_NAME/release/end/unbind_vfio.sh"; fi
    fi
    if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]; then "$SCRIPT_PATH" "$@"; fi
    exit 0
  '');
in {
  options.myModules.libvirtVfioHooks = {
    enable = lib.mkEnableOption "Enable LibVirt VFIO hooks";
    vmName = lib.mkOption { type = lib.types.str; default = ""; };
    devices = lib.mkOption { type = with lib.types; listOf str; default = []; };
    memoryMb = lib.mkOption { type = lib.types.int; default = 0; };
    defaultGovernor = lib.mkOption { type = lib.types.enum ["conservative" "ondemand" "userspace" "powersave" "performance" "schedutil"]; default = "schedutil"; };
  };
  config = lib.mkIf cfg.enable {
    assertions = [ { assertion = cfg.vmName != ""; message = "vmName must be set"; } { assertion = cfg.memoryMb >= 0; message = "memoryMb must be >= 0"; } ];
    virtualisation.libvirtd.hooks.qemu = lib.mkIf (cfg.enable && cfg.vmName != "") { qemu = dispatcherScriptFile; };
    environment.etc = {
      "libvirt/hooks/qemu.d/${cfg.vmName}/prepare/begin/bind_vfio.sh" = { source = bindScriptFile; mode = "0755"; user = "root"; group = "root"; };
      "libvirt/hooks/qemu.d/${cfg.vmName}/release/end/unbind_vfio.sh" = { source = unbindScriptFile; mode = "0755"; user = "root"; group = "root"; };
    };
    environment.systemPackages = [ pkgs.libvirt pkgs.kmod pkgs.gnugrep pkgs.gawk pkgs.pciutils pkgs.procps pkgs.coreutils pkgs.systemd ];
  };
}
# VFIO hooks: bind/unbind devices around a VM lifecycle; options for vmName, devices, hugepages, governor
# Example: myModules.libvirtVfioHooks = { enable = true; vmName = "Win11"; devices = [ "pci_0000_01_00_0" ]; memoryMb = 16384; };