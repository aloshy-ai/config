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

  # Enable the secrets manager
  services.secrets-manager = {
    enable = true;
    # Optional: Specify a remote Git repository for your secrets
    remoteUrl = "https://github.com/aloshy-ai/nix-secrets.git";
    # Path to your SSH key for decryption
    identityFile = "~/.ssh/id_ed25519";
    # Where to export decrypted secrets (default is ~/.secrets)
    exportPath = "~/.secrets";
    # Set your public key for encryption
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMn4QR7tS9Ctt9Jve4WqFMsBQMLu6mIgv4ESOURpwZI";
    # Enable exporting secrets during rebuild
    exportSecrets = true;
    # Enable pulling repository during rebuild
    pullOnRebuild = true;
    # Use safe pull mode to avoid conflicts
    pullMode = "safe";
  };

  # We'll keep the script for backward compatibility
  home.file.".local/bin/decrypt-github-token" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      secrets-helper show GITHUB_TOKEN
    '';
  };

  # Add a script to decrypt the GitHub SSH key
  home.file.".local/bin/decrypt-github-ssh-key" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      secrets-helper show GITHUB_SSH_KEY
    '';
  };

  # Add a generic script to decrypt any secret by name
  home.file.".local/bin/decrypt-secret" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash

      if [ $# -ne 1 ]; then
        echo "Usage: $0 <secret-name>"
        echo "Available secrets:"
        secrets-list
        exit 1
      fi

      SECRET_NAME="$1"

      # Use the secrets-helper to show the secret
      if secrets-helper exists "$SECRET_NAME"; then
        secrets-helper show "$SECRET_NAME"
      else
        echo "Error: Secret '$SECRET_NAME' not found."
        echo "Available secrets:"
        secrets-list
        exit 1
      fi
    '';
  };

  services.mcp-servers = {
    servers = {
      github = {
        enable = true;
        # Use the secrets-helper to get the token
        access-token = "$(secrets-helper show GITHUB_TOKEN)";
      };
      filesystem = {
        enable = true;
        allowed-paths = [
          "$HOME/Desktop"
          "$HOME/Documents"
        ];
      };
    };
  };
}
