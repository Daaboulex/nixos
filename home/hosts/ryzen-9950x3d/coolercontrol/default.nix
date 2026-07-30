{ site, ... }:
{
  # Host-specific CoolerControl settings — merged over module defaults
  myModules.home.coolercontrol.settings = {

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
      # "Ram" fan curve (Graph): nct6799 SYSTIN → fan5 duty. SYSTIN (board temp ~34 °C) is a
      # STABLE RAM proxy — it tracks the DIMM SPD temps (~32 °C) but, being a platform/Super-I/O
      # device (not i2c), its CoolerControl UID never shifts. The spd5118 DIMM temps were
      # abandoned: their i2c BUS number renumbers per boot, so any captured UID goes missing on
      # the next boot → 100 °C failsafe. nct6799 (00a4da18…) is the same device fan5 lives on.
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
            temp_name = "temp1"; # nct6799 SYSTIN (hwmon temp1) — stable board/RAM-proxy temp
            device_uid = site.hosts.ryzen-9950x3d.coolercontrol.nct6799Uid;
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

    # fan5 on the nct6799 follows the "Ram" profile (was GUI-only). The nct6799
    # UID is i2c-enumeration-INDEPENDENT (Super-IO/platform device, unlike the
    # spd5118 i2c sensors) → this fan→profile binding is robust across all profiles.
    devices = {
      ram-fan = {
        uid = site.hosts.ryzen-9950x3d.coolercontrol.nct6799Uid;
        channels = {
          fan5 = {
            profile_uid = "41de40ea-b63b-4d35-9e79-875e491447bc";
          };
        };
      };
    };

  };
}
