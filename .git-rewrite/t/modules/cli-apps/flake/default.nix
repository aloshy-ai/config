inputs@{ options, config, lib, pkgs, ... }:

with lib;
let
  cfg = config.plusultra.cli-apps.flake;
in
{
  options.plusultra.cli-apps.flake = with types; {
    enable = mkBoolOpt false "Whether or not to enable flake.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      snowfallorg.flake
    ];
  };
}
