# ghostty — GPU-accelerated terminal with Breeze-Dark theming and renderer
# compatibility modes for GPUs below the OpenGL 4.3 it requires.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.ghostty;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c theme;

  # Ghostty's renderer hard-requires OpenGL 4.3; the GTK surface aborts
  # (error.OpenGLOutdated) on GPUs that report less. "gl-override" makes Mesa
  # report 4.3 so the gate passes while rendering stays on the GPU — viable
  # where the driver exposes the 4.3 feature set (ARB_compute_shader,
  # ARB_shader_storage_buffer_object) as extensions but caps its reported
  # version at 4.2, e.g. Intel HD 4000 / Ivy Bridge on current Mesa. "software"
  # forces llvmpipe (CPU) for GPUs that genuinely lack the features. The
  # upstream .desktop, D-Bus, and systemd units hardcode the absolute store
  # binary, so PATH-level wrapping is bypassed on GUI/D-Bus launch — repoint all
  # three at the wrapped binary so every entry point inherits the env.
  mkWrapped =
    suffix: env:
    let
      base = pkgs.ghostty;
      flags = lib.concatStringsSep " " (
        lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") env
      );
    in
    pkgs.symlinkJoin {
      name = "${base.name}-${suffix}";
      paths = [ base ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/ghostty ${flags}

        for unit in \
          share/applications/com.mitchellh.ghostty.desktop \
          share/dbus-1/services/com.mitchellh.ghostty.service \
          share/systemd/user/app-com.mitchellh.ghostty.service; do
          real=$(readlink -f "$out/$unit")
          rm "$out/$unit"
          substitute "$real" "$out/$unit" \
            --replace-fail "${base}/bin/ghostty" "$out/bin/ghostty"
        done
      '';
      meta = base.meta // {
        mainProgram = "ghostty";
      };
    };

  renderPackages = {
    gl-override = mkWrapped "gl43" {
      MESA_GL_VERSION_OVERRIDE = "4.3";
      MESA_GLSL_VERSION_OVERRIDE = "430";
    };
    software = mkWrapped "llvmpipe" {
      LIBGL_ALWAYS_SOFTWARE = "1";
      GALLIUM_DRIVER = "llvmpipe";
    };
  };
in
{
  options.myModules.home.ghostty = {
    enable = lib.mkEnableOption "Ghostty terminal emulator";

    renderer = lib.mkOption {
      type = lib.types.enum [
        "native"
        "gl-override"
        "software"
      ];
      default = "native";
      description = ''
        GPU compatibility mode for hosts below Ghostty's required OpenGL 4.3:
        - native: unmodified; aborts with error.OpenGLOutdated on GPUs that
          report < 4.3.
        - gl-override: claim GL 4.3 via MESA_GL_VERSION_OVERRIDE. Rendering stays
          on the GPU; works where the driver exposes the 4.3 feature set as
          extensions but caps its reported version (Intel HD 4000 / Ivy Bridge
          on current Mesa).
        - software: force llvmpipe CPU rendering. Always works; CPU-bound.
      '';
    };

    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # ============================================================================
    # Ghostty (Terminal Emulator)
    # ============================================================================
    programs.ghostty = myLib.mergeSettings {
      defaults = {
        enable = true;
        clearDefaultKeybinds = false; # keep Ghostty's safe defaults (incl. performable escape passthrough)
        enableZshIntegration = lib.mkDefault true;

        settings = {
          # --- KDE-faithful window chrome ---
          window-decoration = lib.mkDefault "server"; # KWin Breeze SSD, not the libadwaita CSD header
          window-theme = lib.mkDefault "dark"; # AdwStyleManager dark; matches Breeze Dark + silences gtk-prefer-dark warning
          gtk-single-instance = lib.mkDefault true; # one process — instant new windows/tabs
          window-show-tab-bar = lib.mkDefault "never"; # no libadwaita tab bar — zellij renders the tabbed view in-cell
          working-directory = lib.mkDefault "home"; # new windows open in $HOME, not the single-instance process cwd
          window-padding-x = lib.mkDefault 6;
          window-padding-y = lib.mkDefault 4;
          window-padding-balance = lib.mkDefault true;
          background-opacity = lib.mkDefault 1; # opaque, matches Konsole Opacity=1

          # --- Cursor (Konsole: blinking block; no cursor-color so it inverts the cell) ---
          cursor-style = lib.mkDefault "block";
          cursor-style-blink = lib.mkDefault true;

          # --- Behaviour ---
          confirm-close-surface = lib.mkDefault false; # seamless close, like Konsole's no-confirm
          copy-on-select = lib.mkDefault "clipboard";
          clipboard-trim-trailing-spaces = lib.mkDefault true;
          mouse-hide-while-typing = lib.mkDefault true;
          auto-update = lib.mkDefault "off"; # updates come from Nix, not Ghostty

          # Deep but bounded scrollback. Konsole's "unlimited" is deliberately
          # not mirrored — unbounded history risks OOM on low-RAM hosts.
          scrollback-limit = lib.mkDefault 100000000; # 100 MB

          font-size = lib.mkDefault 12;
        }
        // lib.optionalAttrs hasTheme {
          font-family = theme.font.family;

          # Breeze-Dark palette — slot mapping mirrors the Konsole
          # BreezeDark-Custom scheme exactly (theme module is the source).
          inherit (c) background;
          inherit (c) foreground;
          selection-background = c.selection;
          selection-foreground = c.foreground-selected;
          palette = [
            "0=${c.background}"
            "1=${c.red}"
            "2=${c.green}"
            "3=${c.orange}"
            "4=${c.blue}"
            "5=${c.purple}"
            "6=${c.blue-alt}"
            "7=${c.foreground-dim}"
            "8=${c.surface}"
            "9=${c.red}"
            "10=${c.green}"
            "11=${c.orange}"
            "12=${c.blue}"
            "13=${c.purple}"
            "14=${c.blue-alt}"
            "15=${c.foreground}"
          ];
        };
      }
      // lib.optionalAttrs (cfg.renderer != "native") {
        package = renderPackages.${cfg.renderer};
      };
      overrides = cfg.settings;
    };
  };
}
