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
      # "Ram" fan curve (Graph): RAM temp (sensor1) → fan5 duty. Was GUI-only.
      # All UIDs here are stable (profile/function UIDs are CC-internal;
      # sensor1's device 19e098e3 is the CustomSensors virtual device, stable).
      ram = {
        uid = "41de40ea-b63b-4d35-9e79-875e491447bc";
        name = "Ram";
        p_type = "Graph";
        speed_profile = [
          {
            temp = 0.0;
            duty = 0;
          }
          {
            temp = 22.2;
            duty = 13;
          }
          {
            temp = 33.6;
            duty = 27;
          }
          {
            temp = 47.0;
            duty = 65;
          }
          {
            temp = 49.0;
            duty = 100;
          }
        ];
        extra = {
          function_uid = "b2e0203d-04fc-4e20-b4b3-b802f25f7ed1";
          temp_source = {
            temp_name = "sensor1";
            device_uid = "19e098e312e1b1b39163a343ea22b6ea17f18ec1a803ffe0ce44f5bacd6076ee";
          };
          temp_min = 0.0;
          temp_max = 49.0;
          offset_profile = [ ];
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
      # "Function for Ram" (Standard) — response smoothing for the Ram profile.
      ram = {
        uid = "b2e0203d-04fc-4e20-b4b3-b802f25f7ed1";
        name = "Function for Ram";
        duty_minimum = 1;
        duty_maximum = 65;
        response_delay = 1;
        deviance = 1.0;
        only_downward = true;
        extra = {
          f_type = "Standard";
          step_size_min_decreasing = 0;
          step_size_max_decreasing = 0;
          threshold_hopping = true;
        };
      };
    };

    # Custom sensor "sensor1": Mix/Max of the 4 RAM DIMM SPD temps (spd5118) →
    # feeds the "Ram" fan profile (fan5 on the nct6799).
    #
    # ⚠ FRAGILE UIDs: CoolerControl derives spd5118 device UIDs from i2c/hwmon
    # enumeration, which the NVIDIA driver's i2c adapters renumber. These are the
    # LIVE set with the nvidia driver loaded (normal profile); they will shift if
    # the i2c/hwmon topology changes (e.g. the 1660S bound to vfio-pci in a VFIO
    # profile). Re-capture via `GET /devices` if the failsafe returns.
    customSensors = {
      sensor1 = {
        id = "sensor1";
        cs_type = "Mix";
        mix_function = "Max";
        sources = [
          {
            temp_source = {
              temp_name = "temp1";
              device_uid = "0395e897c5eba35a0215b2ad1bbbed724a753ababd3687dd7bd8486e87515f2c";
            };
            weight = 1;
          }
          {
            temp_source = {
              temp_name = "temp1";
              device_uid = "a53548590e39153bdd747df79ea58dfa3b432217d37743847498e9375779442f";
            };
            weight = 1;
          }
          {
            temp_source = {
              temp_name = "temp1";
              device_uid = "d4b5586a00eedabdb9404b4a33dea4a70521d7c33a6c0e7bc770aba9513c41d2";
            };
            weight = 1;
          }
          {
            temp_source = {
              temp_name = "temp1";
              device_uid = "8ff88c86e9405c3ab3dc87327f236a6510ecde8929bc72761e3a957a7304162d";
            };
            weight = 1;
          }
        ];
      };
    };

    # fan5 on the nct6799 follows the "Ram" profile (was GUI-only). The nct6799
    # UID is i2c-enumeration-INDEPENDENT (Super-IO/platform device, unlike the
    # spd5118 i2c sensors) → this fan→profile binding is robust across all profiles.
    devices = {
      ram-fan = {
        uid = "00a4da18625f56275c89e2fcd25a83c08c5ad3326452fa7e252fcc8a89c92493";
        channels = {
          fan5 = {
            profile_uid = "41de40ea-b63b-4d35-9e79-875e491447bc";
          };
        };
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
