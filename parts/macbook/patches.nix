# macbook-patches — out-of-tree kernel modules for MacBook hardware.
#
# Two patched drivers maintained against mainline:
#   • applesmc  — race fixes (idev_poll NULL deref, keyboard backlight,
#                 cache access, workqueue cleanup); patch file varies by
#                 kernel version (rewrite in 6.19).
#   • at24      — NULL-guard regulator calls for MacBook SPD EEPROMs
#                 (no VCC regulator → crash on load without this patch).
#
# Kernel version bounds: tested on 6.19 and 6.20. The applesmc-6.19 patch
# was written against the post-rewrite layout; newer kernels may refactor
# again. Review both patches + postPatch seds against the current driver
# source when bumping the kernel to ≥ 6.21.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.macbook.patches;
      inherit (config.boot.kernelPackages) kernel;

      # LLVM flags for Clang-based kernels (CachyOS)
      extraMakeFlags = if (kernel.stdenv.cc.isClang or false) then [ "LLVM=1" ] else [ ];
      extraBuildInputs =
        if (kernel.stdenv.cc.isClang or false) then
          [
            pkgs.llvmPackages.clang-unwrapped
            pkgs.llvmPackages.bintools-unwrapped
            pkgs.llvmPackages.lld
          ]
        else
          [
            pkgs.gcc-unwrapped
            pkgs.binutils-unwrapped
          ];

      # Select applesmc patch based on kernel version — the driver was rewritten in 6.19
      # (static globals → per-device struct), so the patch differs significantly.
      applesmcPatch =
        if lib.versionAtLeast kernel.version "6.19" then
          ./applesmc-6.19-fixes.patch
        else
          ./applesmc-comprehensive-fixes.patch;

      # Patched applesmc — fixes race conditions in keyboard backlight,
      # null pointer dereference in cache access, workqueue flush on cleanup,
      # and NULL smc pointer in accelerometer poller (idev_poll race)
      applesmc-patched = pkgs.stdenv.mkDerivation {
        pname = "applesmc-patched";
        version = "${kernel.version}-patched";
        inherit (kernel) src;
        nativeBuildInputs = kernel.moduleBuildDependencies ++ extraBuildInputs;
        patches = [ applesmcPatch ];
        postPatch = ''
          # 1. Guard applesmc_idev_poll against NULL smc (race during probe)
          sed -i '/^static void applesmc_idev_poll/,/^}$/ {
            /struct applesmc_device \*smc/a\
          \tif (!smc) return;
          }' drivers/hwmon/applesmc.c || true

          # 2. Force port I/O on MacBook Pro 9,2 — MMIO path fails for LKSB
          #    (keyboard backlight). SMC returns error 133 on MMIO reads/writes
          #    for the LKSB key. After ACPI resource walk and ioremap, clear
          #    iomem_base_set for this model to force port I/O for all keys.
          sed -i '/smc->iomem_base = ioremap/,/return 0;/{
            /return 0;/i\
          \t/* MacBookPro9,2: MMIO fails for LKSB key (error 133), force port I/O */\
          \tif (smc->iomem_base_set && dmi_match(DMI_PRODUCT_NAME, "MacBookPro9,2")) {\
          \t\tdev_info(smc->ldev, "MacBookPro9,2: disabling MMIO (LKSB incompatible)\\n");\
          \t\tif (smc->iomem_base) iounmap(smc->iomem_base);\
          \t\tsmc->iomem_base = NULL;\
          \t\tsmc->iomem_base_set = false;\
          \t}
          }' drivers/hwmon/applesmc.c || true

          # 3. Fix brightness_set: dev_get_drvdata(led_cdev->dev) returns NULL because
          #    drvdata is set on the platform device, not the LED device. Use container_of
          #    instead, and remove the nand-disk default trigger which fires brightness_set
          #    during registration (before drvdata could possibly be set).
          sed -i 's|dev_get_drvdata(led_cdev->dev)|container_of(led_cdev, struct applesmc_device, backlight_dev)|' drivers/hwmon/applesmc.c
          sed -i '/default_trigger.*nand-disk/d' drivers/hwmon/applesmc.c

          # Ensure dmi.h is included
          grep -q 'linux/dmi.h' drivers/hwmon/applesmc.c || \
            sed -i '/#include <linux\/err.h>/a #include <linux/dmi.h>' drivers/hwmon/applesmc.c
        '';
        buildPhase = ''
          make -j$NIX_BUILD_CORES -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
            M=$PWD/drivers/hwmon \
            ${lib.concatStringsSep " " extraMakeFlags} \
            KBUILD_MODPOST_WARN=1 \
            modules
        '';
        installPhase = ''
          mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
          cp drivers/hwmon/applesmc.ko $out/lib/modules/${kernel.modDirVersion}/extra/
        '';
      };

      # Patched at24 — NULL-guard regulator calls when no VCC regulator exists (MacBook crash fix).
      # The at24 EEPROM driver assumes a regulator exists. On MacBooks, i2c-i801 probes SPD
      # EEPROMs via at24, but there's no voltage regulator → NULL deref in regulator_enable().
      # Fix: use devm_regulator_get_optional, set vcc_reg=NULL when absent, guard all 6 call sites.
      at24-patched = pkgs.stdenv.mkDerivation {
        pname = "at24-patched";
        version = "${kernel.version}-patched";
        inherit (kernel) src;
        nativeBuildInputs = kernel.moduleBuildDependencies ++ extraBuildInputs;
        postPatch = ''
          cd drivers/misc/eeprom
          # 1. Use _optional so missing regulator returns -ENODEV instead of deferred/error
          sed -i 's/devm_regulator_get(dev, "vcc")/devm_regulator_get_optional(dev, "vcc")/' at24.c
          # 2. Handle -ENODEV by setting vcc_reg = NULL (insert after the get_optional line)
          sed -i '/devm_regulator_get_optional/,/IS_ERR(at24->vcc_reg)/{
            s/if (IS_ERR(at24->vcc_reg))/if (IS_ERR(at24->vcc_reg) \&\& PTR_ERR(at24->vcc_reg) == -ENODEV) { at24->vcc_reg = NULL; } else if (IS_ERR(at24->vcc_reg))/
          }' at24.c
          # 3. Guard all regulator_enable calls
          sed -i 's/regulator_enable(at24->vcc_reg)/at24->vcc_reg ? regulator_enable(at24->vcc_reg) : 0/g' at24.c
          # 4. Guard all regulator_disable calls
          sed -i 's/regulator_disable(at24->vcc_reg)/at24->vcc_reg ? regulator_disable(at24->vcc_reg) : 0/g' at24.c
          cd ../../..
        '';
        buildPhase = ''
          make -j$NIX_BUILD_CORES -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
            M=$PWD/drivers/misc/eeprom \
            ${lib.concatStringsSep " " extraMakeFlags} \
            KBUILD_MODPOST_WARN=1 \
            modules
        '';
        installPhase = ''
          mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
          cp drivers/misc/eeprom/at24.ko $out/lib/modules/${kernel.modDirVersion}/extra/
        '';
      };
    in
    {
      _class = "nixos";
      options.myModules.macbook.patches = {
        enable = lib.mkEnableOption "MacBook kernel patches (AppleSMC fixes, AT24 warning suppression)";
      };
      config = lib.mkIf cfg.enable {
        # Warn (don't block) on kernels newer than the last one tested.
        # The applesmc patch file + postPatch seds were validated on
        # 6.19 and 6.20. 7.0 ships refactors we haven't reviewed. If
        # the patches still apply cleanly, the module builds and loads;
        # if a sed no-ops silently, behaviour quietly reverts to vanilla
        # applesmc; if the patch rejects, the kernel-module build fails
        # LOUDLY during nrb — so either outcome is safe to observe.
        # Keeping this as a warning means the cachyos specialisation
        # (kernel 7.0) isn't blocked pre-emptively.
        warnings =
          lib.optional (!lib.versionOlder kernel.version "6.21")
            "myModules.macbook.patches: kernel ${kernel.version} > 6.20 (last tested). applesmc + at24 patches may no-op silently or fail at module build. Re-verify patch applicability when bumping kernels (parts/macbook/patches.nix).";
        boot.extraModulePackages = [
          applesmc-patched
          at24-patched
        ];
        boot.kernelModules = [
          "applesmc"
          "at24"
        ];
      };
    };
in
{
  flake.modules.nixos.macbook-patches = mod;

}
