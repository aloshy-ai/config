# Command wrappers for devbox integration
{pkgs ? import <nixpkgs> {}}: let
  # Import the operations module
  ops = import ./operations.nix {inherit pkgs;};

  # Create a wrapper for the add-secret command
  addSecretCmd = pkgs.writeShellScriptBin "add-secret-cmd" ''
    #!/usr/bin/env bash

    # Check arguments
    if [ $# -lt 2 ]; then
      echo "Usage: add-secret NAME VALUE"
      exit 1
    fi

    # Extract arguments
    NAME="$1"
    VALUE="$2"

    # Build and run the script
    nix-build -E '
      let
        pkgs = import <nixpkgs> {};
        ops = import ./nix/modules/home/secrets/operations.nix { inherit pkgs; };
        result = ops.addSecret {
          name = "'"$NAME"'";
          value = "'"$VALUE"'";
        };
      in
        result.installScript
    ' --no-out-link | bash
  '';

  # Create a wrapper for the delete-secret command
  deleteSecretCmd = pkgs.writeShellScriptBin "delete-secret-cmd" ''
    #!/usr/bin/env bash

    # Check arguments
    if [ $# -lt 1 ]; then
      echo "Usage: delete-secret NAME"
      exit 1
    fi

    # Extract arguments
    NAME="$1"

    # Build and run the script
    nix-build -E '
      let
        pkgs = import <nixpkgs> {};
        ops = import ./nix/modules/home/secrets/operations.nix { inherit pkgs; };
        result = ops.deleteSecret {
          name = "'"$NAME"'";
        };
      in
        result.removeScript
    ' --no-out-link | bash
  '';

  # Create a wrapper for the list-secrets command
  listSecretsCmd = pkgs.writeShellScriptBin "list-secrets-cmd" ''
    #!/usr/bin/env bash

    # Build and run the script
    nix-build -E '
      let
        pkgs = import <nixpkgs> {};
        ops = import ./nix/modules/home/secrets/operations.nix { inherit pkgs; };
        result = ops.listSecrets {};
      in
        result.listScript
    ' --no-out-link | bash
  '';
in {
  # Export the commands
  inherit
    addSecretCmd
    deleteSecretCmd
    listSecretsCmd
    ;
}
