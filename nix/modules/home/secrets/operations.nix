# operations.nix
# Pure Nix operations for secret management
{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
}: let
  # Import the pure module
  pure = import ./pure.nix {inherit pkgs lib;};

  # Function to add a secret
  addSecret = {
    name,
    value,
    repoPath ? "$HOME/aloshy-ai/nix-secrets",
  }: let
    # Normalize the secret name
    normalizedName = pure.normalizeSecretName name;

    # Create a derivation that produces an encrypted secret
    secretDrv = pkgs.stdenv.mkDerivation {
      name = "secret-${normalizedName}";

      # Use age for encryption
      buildInputs = [pkgs.age];

      # No sources needed
      unpackPhase = "true";

      # Build phase - encrypt the secret
      buildPhase = ''
        # Create the value file
        echo "${value}" > ${normalizedName}.value

        # Encrypt with age
        age -a -r "${pure.config.publicKey}" -o ${normalizedName}.age ${normalizedName}.value

        # Clean up
        rm ${normalizedName}.value
      '';

      # Install phase - copy encrypted file
      installPhase = ''
        mkdir -p $out
        cp ${normalizedName}.age $out/
      '';
    };

    # Create a derivation to handle adding the secret to the secrets.nix file
    updateDrv = pkgs.stdenv.mkDerivation {
      name = "add-secret-${normalizedName}";

      # No sources needed
      unpackPhase = "true";

      # No build phase needed
      buildPhase = "true";

      # Create the installation script
      installPhase = ''
        mkdir -p $out

        # Create the installation script
        cat > $out/install.sh << EOF
        #!/usr/bin/env bash
        set -e

        REPO_PATH="\$1"
        SECRET_NAME="${normalizedName}"
        ENCRYPTED_FILE="${secretDrv}/${normalizedName}.age"

        # Check if the repo exists
        if [ ! -d "\$REPO_PATH" ]; then
          echo "Creating secrets repository at \$REPO_PATH"
          mkdir -p "\$REPO_PATH"
        fi

        # Copy the encrypted file
        cp "\$ENCRYPTED_FILE" "\$REPO_PATH/\$SECRET_NAME.age"
        chmod 600 "\$REPO_PATH/\$SECRET_NAME.age"

        # Update the secrets.nix file
        if [ -f "\$REPO_PATH/secrets.nix" ]; then
          # Check if the secret is already defined
          if ! grep -q "secrets.\$SECRET_NAME" "\$REPO_PATH/secrets.nix"; then
            # Add the secret to the file
            sed -i '/# Secret definitions are automatically added here by the add-secret function/a \\n  # ${normalizedName}\\n  secrets.${normalizedName} = {};' "\$REPO_PATH/secrets.nix"
            echo "Updated secrets.nix - added entry for \$SECRET_NAME"
          else
            echo "Secret \$SECRET_NAME already exists in secrets.nix"
          fi
        else
          # Create a new secrets.nix file
          cat > "\$REPO_PATH/secrets.nix" << 'EOF2'
        {
          # Users who can access secrets
          users = {
            # Add your user here
            # username = {
            #   publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMn4QR7tS9Ctt9Jve4WqFMsBQMLu6mIgv4ESOURpwZI";
            # };
          };

          # Secret definitions are automatically added here by the add-secret function

          # ${normalizedName}
          secrets.${normalizedName} = {};
        }
        EOF2
          echo "Created new secrets.nix with entry for \$SECRET_NAME"
        fi

        echo "Secret \$SECRET_NAME added to \$REPO_PATH"
        echo "Don't forget to commit and push the changes to the repository"
        EOF

        chmod +x $out/install.sh
      '';
    };

    # Create an install script
    installScript = pkgs.writeShellScript "add-secret-${normalizedName}" ''
      #!/usr/bin/env bash
      set -e

      # Run the installation script
      "${updateDrv}/install.sh" "${repoPath}"
    '';
  in {
    inherit normalizedName secretDrv updateDrv installScript;
  };

  # Function to delete a secret
  deleteSecret = {
    name,
    repoPath ? "$HOME/aloshy-ai/nix-secrets",
  }: let
    # Normalize the secret name
    normalizedName = pure.normalizeSecretName name;

    # Create a derivation to handle deleting the secret
    deleteDrv = pkgs.stdenv.mkDerivation {
      name = "delete-secret-${normalizedName}";

      # No sources needed
      unpackPhase = "true";

      # No build phase needed
      buildPhase = "true";

      # Create the removal script
      installPhase = ''
        mkdir -p $out

        # Create the removal script
        cat > $out/remove.sh << EOF
        #!/usr/bin/env bash
        set -e

        REPO_PATH="\$1"
        SECRET_NAME="${normalizedName}"

        # Check if the secret exists
        if [ ! -f "\$REPO_PATH/\$SECRET_NAME.age" ]; then
          echo "Secret \$SECRET_NAME does not exist in \$REPO_PATH"
          exit 1
        fi

        # Remove the secret file
        rm -f "\$REPO_PATH/\$SECRET_NAME.age"

        # Update the secrets.nix file
        if [ -f "\$REPO_PATH/secrets.nix" ]; then
          # Remove the entry for this secret
          sed -i "/secrets.\$SECRET_NAME/d" "\$REPO_PATH/secrets.nix"
          echo "Updated secrets.nix - removed entry for \$SECRET_NAME"
        fi

        echo "Secret \$SECRET_NAME deleted from \$REPO_PATH"
        echo "Don't forget to commit and push the changes to the repository"
        EOF

        chmod +x $out/remove.sh
      '';
    };

    # Create a removal script
    removeScript = pkgs.writeShellScript "delete-secret-${normalizedName}" ''
      #!/usr/bin/env bash
      set -e

      # Run the removal script
      "${deleteDrv}/remove.sh" "${repoPath}"
    '';
  in {
    inherit normalizedName deleteDrv removeScript;
  };

  # Function to list secrets
  listSecrets = {repoPath ? "$HOME/aloshy-ai/nix-secrets"}: let
    # Create a derivation to handle listing secrets
    listingDrv = pkgs.stdenv.mkDerivation {
      name = "list-secrets";

      # No sources needed
      unpackPhase = "true";

      # No build phase needed
      buildPhase = "true";

      # Create the listing script
      installPhase = ''
        mkdir -p $out

        # Create the listing script
        cat > $out/list.sh << EOF
        #!/usr/bin/env bash
        set -e

        REPO_PATH="\$1"

        # Check if the repo exists
        if [ ! -d "\$REPO_PATH" ]; then
          echo "Secrets repository does not exist at \$REPO_PATH"
          exit 1
        fi

        # Check for age files
        if [ ! -f "\$REPO_PATH"/*.age ]; then
          echo "No secrets found in \$REPO_PATH"
          exit 0
        fi

        # List all .age files
        echo "Secrets in \$REPO_PATH:"
        for secret in "\$REPO_PATH"/*.age; do
          if [ -f "\$secret" ]; then
            basename=\$(basename "\$secret" .age)
            echo "  - \$basename"
          fi
        done
        EOF

        chmod +x $out/list.sh
      '';
    };

    # Generate a listing script
    listScript = pkgs.writeShellScript "list-secrets" ''
      #!/usr/bin/env bash

      # Run the listing script
      "${listingDrv}/list.sh" "${repoPath}"
    '';
  in {
    inherit listScript;
  };
in {
  inherit
    addSecret
    deleteSecret
    listSecrets
    ;
}
