{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  system, # The system architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
  format, # A normalized name for the system target (eg. `iso`).
  virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
  systems, # An attribute map of your defined hosts.
  # All other arguments come from the module system.
  config,
  ...
}: {
  # Your configuration.
  nix-homebrew = {
    user = "aloshy";
    enable = true;
    mutableTaps = false;
    autoMigrate = true;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # cleanup = "zap";
    };

    brews = [
      "nvm"
    ];

    casks = [
      "cursor"
      "webstorm"
      "tailscale"
      "claude"
      "docker"
      "opera"
      "rustdesk"
    ];

    # taps = [
    #   "homebrew/services"
    # ];

    masApps = {
      "CopyClip" = 595191960;
      "WireGuard" = 1451685025;
      "DisplayMyIP" = 1493408723;
    };
  };
}
