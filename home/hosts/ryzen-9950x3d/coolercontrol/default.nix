{
  # Host-specific CoolerControl settings — merged over module defaults
  myModules.home.coolercontrol.settings = {
    enable = true;

    profiles = {
      default-profile = {
        uid = "0";
        name = "Default Profile";
        p_type = "Default";
        extra = {
          function_uid = "0";
        };
      };
      my-profile = {
        uid = "0840dd7f-04cb-4c72-9303-4d78f0e92a55";
        name = "My Profile";
        p_type = "Default";
        extra = {
          function_uid = "02ba5ea0-89cc-4085-808f-c3b1cc97963b";
        };
      };
    };

    functions = {
      default-function = {
        uid = "0";
        name = "Default Function";
        duty_minimum = 1;
        duty_maximum = 100;
      };
      my-function = {
        uid = "02ba5ea0-89cc-4085-808f-c3b1cc97963b";
        name = "My Function";
        duty_minimum = 2;
        duty_maximum = 100;
      };
    };

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
