{
  lib,
  options,
  ...
}:

{
  # ============================================================================
  # CoolerControl — Declarative fan/cooling daemon configuration via REST API
  # ============================================================================
  # Two-layer architecture:
  #   NixOS  (parts/coolercontrol.nix) → daemon service, XDG autostart
  #   HM     (this module)             → user-facing config via REST API
  #
  # The external coolercontrol-nix module (imported via sharedModules) provides
  # the full option interface with these sections:
  #   - url:           daemon HTTPS endpoint
  #   - profiles:      fan curve profiles (attrsOf submodule)
  #   - functions:     response functions for profiles (attrsOf submodule)
  #   - modes:         device-channel-profile assignments (attrsOf submodule)
  #   - activeMode:    mode UID to activate on login (nullable str)
  #   - alerts:        temperature threshold alerts (listOf submodule)
  #   - settings:      global daemon settings (submodule, 11 fields)
  #   - extraCommands: additional API calls on login (listOf str)
  #
  # This wrapper defaults all scalar/behavioral options. Host configs set
  # hardware-specific values: profiles, functions, modes, alerts, activeMode.
  #
  # Applied via systemd user service on login (coolercontrol REST API).
  # Auth: save an access token to ~/.config/coolerctl/token
  #
  # Guarded: only applies when the coolercontrol-nix HM module is loaded.

  config = lib.optionalAttrs (options.programs ? coolercontrol) {
    programs.coolercontrol = {

      # ── Daemon URL ─────────────────────────────────────────────────────
      # HTTPS endpoint for the coolercontrold REST API.
      # Uses self-signed certs; cookie-based auth after Basic login.
      url = lib.mkDefault "https://localhost:11987";

      # ── Profiles ───────────────────────────────────────────────────────
      # Fan curve profiles. Each profile has:
      #   uid:           str — daemon-assigned UUID
      #   name:          str — display name
      #   p_type:        str — "Default", "Fixed", "Graph", "Mix"
      #   speed_fixed:   int (0-100) — duty for Fixed type
      #   speed_profile: listOf {temp, duty} — curve points for Graph type
      #   extra:         attrs — additional fields (e.g. function_uid)
      # Set per-host: UIDs come from the daemon, tied to discovered devices.

      # ── Functions ──────────────────────────────────────────────────────
      # Response functions that profiles reference. Each function has:
      #   uid:            str — daemon-assigned UUID
      #   name:           str — display name
      #   duty_minimum:   int (0-100) — minimum fan duty %
      #   duty_maximum:   int (0-100) — maximum fan duty %
      #   response_delay: int — seconds before responding to temp change
      #   deviance:       int — temperature hysteresis in °C
      #   only_downward:  bool — only allow downward speed changes
      #   sample_window:  int — temperature averaging window in seconds
      #   extra:          attrs — additional fields
      # Set per-host: UIDs come from the daemon.

      # ── Modes ──────────────────────────────────────────────────────────
      # Named groups of profile-to-device-channel assignments. Each mode has:
      #   uid:             str — daemon-assigned UUID
      #   name:            str — display name
      #   device_settings: attrsOf (attrsOf attrs) — device → channel → profile
      #   extra:           attrs — additional fields
      # Set per-host: maps specific devices/channels to profiles.

      # ── Active mode ────────────────────────────────────────────────────
      # activeMode: nullable str — mode UID to activate on login.
      # Set per-host: selects which mode's profile assignments take effect.

      # ── Alerts ─────────────────────────────────────────────────────────
      # Temperature threshold alerts. Each alert has:
      #   channel:           str — temperature source channel name
      #   threshold_celsius: int — trigger temperature in °C
      #   trigger:           str — "above" or "below"
      #   extra:             attrs — additional fields (notification, action)
      # Set per-host: thresholds depend on specific hardware.

      # ── Global settings ────────────────────────────────────────────────
      # Daemon-wide behaviour. All 11 fields from the CoolerControl daemon.
      settings = lib.mkDefault {
        # Re-apply profiles/modes on system boot
        apply_on_boot = true;

        # Skip device initialisation on daemon start (for debugging)
        no_init = false;

        # Seconds to wait after boot before applying settings
        # Allows devices to fully initialise before being configured
        startup_delay = 2;

        # ThinkPad-specific: allow fans to exceed firmware speed limits
        # Only relevant on Lenovo ThinkPad hardware
        thinkpad_full_speed = false;

        # Handle dynamically appearing/disappearing temperature sources
        # Useful for external sensors or hotplug devices
        handle_dynamic_temps = false;

        # Enable liquidctl integration for AIO coolers (Kraken, Commander, etc.)
        liquidctl_integration = true;

        # Hide duplicate device entries (same physical device, multiple paths)
        hide_duplicate_devices = true;

        # Compress API responses (reduces bandwidth for remote access)
        compress = true;

        # Sensor polling interval in seconds (0.5 - 5.0)
        # Lower = more responsive but higher CPU usage
        poll_rate = 1.0;

        # Suspend drivetemp monitoring during disk sleep
        # Prevents waking drives for temperature reads
        drivetemp_suspend = true;

        # Require HTTPS for API connections (disable for HTTP access)
        allow_unencrypted = false;
      };

      # ── Extra commands ─────────────────────────────────────────────────
      # Additional API calls to execute after applying config on login.
      # extraCommands: listOf str — set per-host for additional commands.
    };
  };
}
