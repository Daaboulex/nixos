# /modules/nixos/hardware/yeetmouse/devices/g502.nix
# Applies specific YeetMouse settings for the Logitech G502
# for both Lightspeed Receiver and Wired connections.
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.myModules.hardware.yeetmouse.devices.g502;
  
  # Helper to access settings concisely
  s = cfg.settings;

  # Script to apply settings
  yeetmouseConfigScript = pkgs.writeShellScriptBin "yeetmouse-g502-config" ''
    #!${pkgs.runtimeShell}
    set -e
    echo "Applying YeetMouse parameters for detected Logitech G502"
    echo "Settings: Sens=${toString s.sensitivity}, Rot=${toString s.rotation}"

    sleep 0.2 # Give module time

    SYSFS_BASE="/sys/module/yeetmouse/parameters"

    if [ ! -d "$SYSFS_BASE" ]; then
      echo "ERROR: Sysfs directory $SYSFS_BASE not found. Is yeetmouse module loaded?" >&2
      exit 1
    fi

    write_param() {
      local param_name="$1"
      local value="$2"
      local path="$SYSFS_BASE/$param_name"
      if [ -w "$path" ]; then
        echo "$value" > "$path"; echo "  Set $param_name = $value"
      else
        echo "  WARN: Cannot write to $path" >&2
      fi
    }
    # Write parameters
    # Sysfs 'Sensitivity' = Global or X axis.
    # Sysfs 'SensitivityY' = Y axis.
    
    val_sens="${toString s.sensitivity}"
    write_param Sensitivity "$val_sens"

    # Only write SensitivityY if explicitly set.
    # If unset (null), the driver handles isotropy naturally (applying Global Sensitivity to both).
    # Writing both explicitly caused issues for the user.
    ${if s.sensitivityY != null then ''
      write_param SensitivityY "${toString s.sensitivityY}"
    '' else ''
      # Optional: Explicitly unset or zero it if the driver supports it to force reset?
      # For now, just NOT writing it should let the driver use the Global value for Y.
    ''}

    write_param RotationAngle "${toString s.rotation}"
    write_param Acceleration "${toString s.acceleration}"
    write_param Midpoint "${toString s.midpoint}"
    write_param UseSmoothing "${if s.useSmoothing then "1" else "0"}"
    write_param AccelerationMode "${toString s.accelerationModeNum}"
    write_param PreScale "${toString s.preScale}"
    write_param Offset "${toString s.offset}"
    write_param InputCap "${toString s.inputCap}"
    write_param OutputCap "${toString s.outputCap}"

    update_path="$SYSFS_BASE/update"
    if [ -w "$update_path" ]; then
      echo "1" > "$update_path"; echo "  Triggered update."
    fi

    echo "G502 parameter script finished."
  '';

in
{
  options.myModules.hardware.yeetmouse.devices.g502 = {
    enable = mkEnableOption "YeetMouse handling for Logitech G502 (Wired/Wireless)";

    wiredProductId = mkOption {
      type = types.str;
      default = "c08d";
      description = "Product ID for the wired G502 mouse (check with lsusb)";
    };

    wirelessProductId = mkOption {
      type = types.str;
      default = "c539";
      description = "Product ID for the Lightspeed Receiver";
    };

    settings = {
      sensitivity = mkOption { type = types.float; default = 0.3125; description = "Global/X Sensitivity"; };
      sensitivityY = mkOption { 
        type = types.nullOr types.float; 
        default = null; 
        description = "Y Sensitivity (Defaults to global sensitivity if null for 1:1 ratio)"; 
      };
      
      # Driver parameters
      rotation = mkOption { type = types.float; default = -0.05236; description = "Rotation angle in radians"; };
      acceleration = mkOption { type = types.float; default = 1.5; description = "Acceleration gain"; };
      midpoint = mkOption { type = types.float; default = 6.65; description = "Acceleration midpoint"; };
      useSmoothing = mkOption { type = types.bool; default = false; description = "Enable smoothing"; };
      accelerationModeNum = mkOption { type = types.int; default = 5; description = "Mode number (5 = Jump)"; };
      preScale = mkOption { type = types.float; default = 1.0; description = "Pre-scale factor"; };
      offset = mkOption { type = types.float; default = 0.0; description = "Offset value"; };
      inputCap = mkOption { type = types.float; default = 0.0; description = "Input cap"; };
      outputCap = mkOption { type = types.float; default = 0.0; description = "Output cap"; };
    };
  };

  config = mkIf cfg.enable {

    # --- Udev Rules ---
    services.udev.extraRules = ''
      # Rule 1: Match Lightspeed Receiver
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="${cfg.wirelessProductId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="yeetmouse-g502-config.service", RUN+="${pkgs.kmod}/bin/modprobe yeetmouse", ATTR{driver_override}="yeetmouse"

      # Rule 2: Match Wired G502
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="${cfg.wiredProductId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="yeetmouse-g502-config.service", RUN+="${pkgs.kmod}/bin/modprobe yeetmouse", ATTR{driver_override}="yeetmouse"
    '';

    # --- Libinput Configuration: FLAT Profile (No Acceleration) ---
    # This CRITICAL setting ensures libinput doesn't apply additional acceleration
    # on top of YeetMouse's custom acceleration curve. Without this, mouse feels
    # faster than Windows even with identical Raw Accel settings.
    services.udev.extraHwdb = ''
      # Logitech G502 - Force flat acceleration profile for YeetMouse
      evdev:input:b0003v046Dp${lib.toUpper cfg.wirelessProductId}*
       MOUSE_DPI=1600@1000
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat

      evdev:input:b0003v046Dp${lib.toUpper cfg.wiredProductId}*
       MOUSE_DPI=1600@1000
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat

      # Match actual input device ID exposed by driver/kernel (0x407F)
      evdev:input:b0003v046Dp407F*
       MOUSE_DPI=1600@1000
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat

      # Generic fallback by name for any G502 variant
      evdev:name:Logitech G502*
       MOUSE_DPI=1600@1000
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat
    '';

    # --- Systemd Service ---
    systemd.services.yeetmouse-g502-config = {
      description = "Apply YeetMouse parameters for Logitech G502";
      path = [ pkgs.coreutils pkgs.runtimeShell ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${yeetmouseConfigScript}/bin/yeetmouse-g502-config";
      };
    };

    # Ensure the yeetmouse driver is requested to be loaded at boot.
    boot.kernelModules = [ "yeetmouse" ];
  };
}