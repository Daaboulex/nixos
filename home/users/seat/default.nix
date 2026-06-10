# seat — Seat B (multiseat) home-manager manifest. A lean second-user desktop for
# the nvidia 1660S seat: a browser + Discord + Steam-adjacent gaming tools, nothing
# more. Imported on top of the shared home/modules catalog (every module is
# enable-gated) by the `multiseat` specialisation, so ONLY the set turned on here is
# active for this user.
#
# DELIBERATELY EXCLUDED (Seat A owns these, or not wanted on a gaming seat):
#   goxlr · streamcontroller · coolercontrol · lact  — Seat A's single-device daemons
#   lsfg-vk                                          — no frame-gen on this seat
#   virt-manager / looking-glass / VFIO tooling      — no VM/passthrough stuff
#   editors / compilers / dev + admin CLIs           — this is not a workstation seat
# yeetmouse is NOT an HM toggle: it's a GLOBAL kernel accel driver with no per-seat
# scope, so the multiseat spec turns it OFF system-wide (Seat B gets raw libinput input).
# Steam is system-wide (programs.steam), so it is already available with no HM toggle.
{
  home.stateVersion = "26.11";

  myModules.home = {
    flatpak.enable = true; # browser + GoofCord (see services.flatpak.packages below)
    protonplus.enable = true; # Proton/Wine version manager for Steam
    heroic.enable = true; # Heroic — Epic / GOG / Amazon games launcher
    mangohud.enable = false; # in-game performance overlay (off per user)
    mangojuice.enable = false; # MangoHud configuration GUI (off per user)
    gamescope.enable = true; # per-title micro-compositor for demanding games
    vkbasalt.enable = true; # Vulkan post-processing
    ghostty.enable = true; # terminal
  };

  # Browser + Discord as Flatpaks (mirrors Seat A's choices), installed for this user.
  services.flatpak.packages = [
    "io.github.milkshiift.GoofCord"
    "io.gitlab.librewolf-community"
    "io.github.ungoogled_software.ungoogled_chromium"
  ];
}
