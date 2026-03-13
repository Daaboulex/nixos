{
  # --------------------------------------------------------------------------
  # CoolerControl — Declarative daemon configuration via REST API
  # --------------------------------------------------------------------------
  # NixOS module (parts/coolercontrol.nix) handles: daemon service, GUI autostart.
  # HM module (coolercontrol-nix) applies: profiles, functions, modes, settings
  #   via REST API on login.
  # --------------------------------------------------------------------------
  #
  # ── Devices (auto-discovered by daemon) ───────────────────────────────
  # c1c4f573... = AMD Ryzen 9 9950X3D 16-Core Processor (zenpower)
  # 97910386... = amdgpu (RX 9070 XT, dGPU)
  # 85f7ac99... = amdgpu (Zen 5 iGPU)
  # 00a4da18... = nct6799 (Nuvoton Super IO — motherboard fans/temps)
  # 6d27c1d0... = drivetemp (ST2000DM001-1ER1 HDD)
  # e77ebb4f... = nvme0 (Samsung SSD 9100 PRO 2TB)
  # 3087c69a... = nvme1 (Samsung SSD 9100 PRO 2TB)
  # 2cfa9672... = r8169_0_e00:00 (Realtek 2.5GbE NIC)
  # 601e430e... / 737b1c28... / 4af5e5f8... / 93a9b924... = spd5118 (DDR5 SPD hub temps)
  #
  # Auth: save an access token to ~/.config/coolerctl/token
  # --------------------------------------------------------------------------
  programs.coolercontrol = {
    enable = true;

    # ── Profiles (fan curve definitions) ──────────────────────────────────
    profiles = {
      # Built-in default profile (daemon-created, uid "0")
      default-profile = {
        uid = "0";
        name = "Default Profile";
        p_type = "Default";
        extra = {
          function_uid = "0";
        };
      };
      # Custom profile
      my-profile = {
        uid = "0840dd7f-04cb-4c72-9303-4d78f0e92a55";
        name = "My Profile";
        p_type = "Default";
        extra = {
          function_uid = "02ba5ea0-89cc-4085-808f-c3b1cc97963b";
        };
      };
    };

    # ── Functions (response behaviour for profiles) ───────────────────────
    functions = {
      # Built-in identity function (daemon-created, uid "0")
      default-function = {
        uid = "0";
        name = "Default Function";
        duty_minimum = 0;
        duty_maximum = 100;
      };
      # Custom function
      my-function = {
        uid = "02ba5ea0-89cc-4085-808f-c3b1cc97963b";
        name = "My Function";
        duty_minimum = 2;
        duty_maximum = 100;
      };
    };

    # ── Modes ─────────────────────────────────────────────────────────────
    # No modes configured (empty in daemon state)

    # ── Active mode ───────────────────────────────────────────────────────
    # No active mode (null in daemon state)

    # ── Alerts ────────────────────────────────────────────────────────────
    # No alerts configured (empty in daemon state)

    # ── Global settings ───────────────────────────────────────────────────
    # All 11 daemon settings fields, matching /etc/coolercontrol/config.toml
    settings = {
      apply_on_boot = true;
      no_init = false;
      startup_delay = 2;
      thinkpad_full_speed = false;
      handle_dynamic_temps = false;
      liquidctl_integration = true;
      hide_duplicate_devices = true;
      compress = true;
      poll_rate = 1.0;
      drivetemp_suspend = true;
      allow_unencrypted = false;
    };
  };
}
