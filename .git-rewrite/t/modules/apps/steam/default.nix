{ options, config, lib, pkgs, ... }:

with lib;
let cfg = config.plusultra.apps.steam;
in
{
  options.plusultra.apps.steam = with types; {
    enable = mkBoolOpt false "Whether or not to enable support for Steam.";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.steam.remotePlay.openFirewall = true;

    hardware.steam-hardware.enable = true;

    # Enable GameCube controller support.
    services.udev.packages = [ pkgs.dolphinEmu ];

    environment.systemPackages = with pkgs.plusultra; [
      steam
    ];
  };
}
