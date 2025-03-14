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
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}: {
  # Your configuration.
  home.stateVersion = "25.05";
  snowfallorg.user.enable = true;

  # Re-enable the original secrets manager
  services.secrets-manager = {
    enable = true; # Re-enable the service
    remoteUrl = "https://github.com/aloshy-ai/nix-secrets.git";
    identityFile = "~/.ssh/id_ed25519";
    exportPath = "~/.secrets";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMn4QR7tS9Ctt9Jve4WqFMsBQMLu6mIgv4ESOURpwZI";
    exportSecrets = true;
    pullOnRebuild = true;
    pullMode = "safe";
  };

  # Homeage has been removed as per user request
}
