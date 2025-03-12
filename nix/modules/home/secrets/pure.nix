{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
}: let
  # Configuration
  config = {
    # Path to the secrets repository
    secretsRepo = "$HOME/aloshy-ai/nix-secrets";

    # Public key for encryption
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMn4QR7tS9Ctt9Jve4WqFMsBQMLu6mIgv4ESOURpwZI";

    # Recipient name for age
    recipientName = "aloshy";
  };

  # Pure Nix function for normalizing secret names
  normalizeSecretName = name:
    builtins.replaceStrings [" "] ["_"] (lib.strings.toUpper name);

  # Function to check if a string has a suffix
  hasSuffix = suffix: str: let
    lenStr = builtins.stringLength str;
    lenSuffix = builtins.stringLength suffix;
  in
    lenStr
    >= lenSuffix
    && builtins.substring (lenStr - lenSuffix) lenSuffix str == suffix;

  # Function to remove a suffix from a string
  removeSuffix = suffix: str: let
    lenStr = builtins.stringLength str;
    lenSuffix = builtins.stringLength suffix;
  in
    if hasSuffix suffix str
    then builtins.substring 0 (lenStr - lenSuffix) str
    else str;

  # Function to extract secret names from a list of files
  extractSecretNames = files:
    builtins.map
    (file: removeSuffix ".age" (builtins.baseNameOf file))
    (builtins.filter (file: hasSuffix ".age" file) files);

  # Parse a secrets.nix file
  parseSecretsFile = file: let
    contents =
      if builtins.pathExists file
      then builtins.readFile file
      else "{}";
    expr = builtins.fromJSON contents;
  in
    expr;

  # Function to create a derivation for adding a secret
  mkAddSecretDerivation = {
    name,
    value ? null,
  }: let
    normalizedName = normalizeSecretName name;

    # Create a derivation that helps with adding secrets
    derivation = pkgs.runCommand "add-secret-${normalizedName}" {} ''
      mkdir -p $out

      # Create temporary files
      echo '${value}' > $out/secret.value

      # Encrypt the secret
      ${pkgs.age}/bin/age -r "${config.publicKey}" -o $out/${normalizedName}.age $out/secret.value

      # Cleanup
      rm $out/secret.value

      # Create installation script
      cat > $out/install.sh << EOF
      #!/usr/bin/env bash
      set -e

      REPO_PATH="\$1"
      SECRET_NAME="${normalizedName}"

      # Check if the repo exists
      if [ ! -d "\$REPO_PATH" ]; then
        echo "Creating secrets repository at \$REPO_PATH"
        mkdir -p "\$REPO_PATH"
      fi

      # Copy the encrypted file
      cp "$out/${normalizedName}.age" "\$REPO_PATH/\$SECRET_NAME.age"
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
          ${config.recipientName} = {
            publicKey = "${config.publicKey}";
          };
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
  in {
    inherit normalizedName derivation;
  };

  # Function to create a derivation for deleting a secret
  mkDeleteSecretDerivation = {name}: let
    normalizedName = normalizeSecretName name;

    # Create a derivation that helps with deletion
    derivation = pkgs.runCommand "delete-secret-${normalizedName}" {} ''
      mkdir -p $out

      # Create deletion script
      cat > $out/delete-secret.sh << EOF
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
        sed -i "/secrets\.\$SECRET_NAME/d" "\$REPO_PATH/secrets.nix"
        echo "Updated secrets.nix - removed entry for \$SECRET_NAME"
      fi

      echo "Secret \$SECRET_NAME deleted from \$REPO_PATH"
      EOF

      chmod +x $out/delete-secret.sh
    '';
  in {
    inherit normalizedName derivation;
  };

  # Function to create a derivation for listing secrets
  mkListSecretsDerivation = repoPath:
    pkgs.runCommand "list-secrets" {} ''
      mkdir -p $out

      # Create the listing script
      cat > $out/list-secrets.sh << EOF
      #!/usr/bin/env bash
      set -e

      REPO_PATH="${repoPath}"

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

      chmod +x $out/list-secrets.sh
    '';
in {
  # Export the pure functions
  inherit
    normalizeSecretName
    mkAddSecretDerivation
    mkDeleteSecretDerivation
    mkListSecretsDerivation
    parseSecretsFile
    hasSuffix
    removeSuffix
    ;

  # Export the configuration
  inherit config;
}
