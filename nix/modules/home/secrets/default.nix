{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  # Import the operations module
  ops = import ./operations.nix {inherit pkgs;};

  # Import the pure module
  pure = import ./pure.nix {inherit pkgs;};

  cfg = config.services.secrets-manager;

  # Location of the secrets repository
  secretsRepoPath = "${config.home.homeDirectory}/aloshy-ai/nix-secrets";

  # Determine the identity file (with tilde expansion)
  identityFile =
    if (hasPrefix "~/" cfg.identityFile)
    then replaceStrings ["~/"] ["${config.home.homeDirectory}/"] cfg.identityFile
    else cfg.identityFile;

  # Secret export path (with tilde expansion)
  exportPath =
    if (hasPrefix "~/" cfg.exportPath)
    then replaceStrings ["~/"] ["${config.home.homeDirectory}/"] cfg.exportPath
    else cfg.exportPath;

  # Helper script for accessing secrets - created as a Nix derivation
  secretsHelper = pkgs.writeTextFile {
    name = "secrets-helper";
    destination = "/bin/secrets-helper";
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -e

      # Configuration
      SECRETS_DIR="${exportPath}"

      # Command line processing
      command=$1
      secret_name=$2

      # Usage information
      show_usage() {
        echo "Usage: secrets-helper COMMAND [SECRET_NAME]"
        echo ""
        echo "Commands:"
        echo "  list          List all available secrets"
        echo "  get SECRET    Get the path to a specific secret file"
        echo "  show SECRET   Show the content of a secret"
        echo "  exists SECRET Check if a secret exists (exit code 0 if exists, 1 if not)"
        echo ""
        echo "Examples:"
        echo "  secrets-helper list"
        echo "  secrets-helper get API_KEY"
        echo "  secrets-helper show API_KEY"
        echo "  secrets-helper exists API_KEY && echo \"Secret exists\""
        exit 1
      }

      # Check if secrets directory exists
      if [[ ! -d "$SECRETS_DIR" ]]; then
        if [ "$command" = "exists" ]; then
          # Quietly fail for exists command
          exit 1
        elif [ "$command" = "show" ]; then
          # For show, return empty string when secret doesn't exist
          exit 0
        else
          echo "Error: Secrets directory does not exist: $SECRETS_DIR"
          echo "Make sure your secrets export is configured correctly"
          exit 1
        fi
      fi

      # Normalize secret name to match our naming convention
      normalize_secret_name() {
        local name=$1
        echo "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
      }

      # Process commands
      case "$command" in
        "list")
          echo "Available secrets:"
          ls -1 "$SECRETS_DIR" | sort
          ;;
        "get")
          if [[ -z "$secret_name" ]]; then
            show_usage
          fi
          NORMALIZED_SECRET=$(normalize_secret_name "$secret_name")
          if [[ -f "$SECRETS_DIR/$NORMALIZED_SECRET" ]]; then
            echo "$SECRETS_DIR/$NORMALIZED_SECRET"
          else
            echo "Error: Secret not found: $secret_name"
            exit 1
          fi
          ;;
        "show")
          if [[ -z "$secret_name" ]]; then
            show_usage
          fi
          NORMALIZED_SECRET=$(normalize_secret_name "$secret_name")
          if [[ -f "$SECRETS_DIR/$NORMALIZED_SECRET" ]]; then
            cat "$SECRETS_DIR/$NORMALIZED_SECRET"
          else
            # Return empty string when secret doesn't exist
            # This allows scripts to handle missing secrets gracefully
            exit 0
          fi
          ;;
        "exists")
          if [[ -z "$secret_name" ]]; then
            show_usage
          fi
          NORMALIZED_SECRET=$(normalize_secret_name "$secret_name")
          if [[ -f "$SECRETS_DIR/$NORMALIZED_SECRET" ]]; then
            exit 0
          else
            exit 1
          fi
          ;;
        *)
          show_usage
          ;;
      esac
    '';
  };

  # Create add-secret.nix function - inline instead of loading from file
  addSecretFunction = ''
    { name, value ? null }:
    let
      pkgs = import <nixpkgs> {};
      ops = import ${./operations.nix} { inherit pkgs; lib = pkgs.lib; };

      result = ops.addSecret {
        inherit name value;
        repoPath = "${secretsRepoPath}";
      };
    in
      result
  '';

  # Create delete-secret.nix function - inline instead of loading from file
  deleteSecretFunction = ''
    { name }:
    let
      pkgs = import <nixpkgs> {};
      ops = import ${./operations.nix} { inherit pkgs; lib = pkgs.lib; };

      result = ops.deleteSecret {
        inherit name;
        repoPath = "${secretsRepoPath}";
      };
    in
      result
  '';

  # Create list-secrets.nix function - inline instead of loading from file
  listSecretsFunction = ''
    {}:
    let
      pkgs = import <nixpkgs> {};
      ops = import ${./operations.nix} { inherit pkgs; lib = pkgs.lib; };

      # List the secrets
      result = ops.listSecrets {
        repoPath = "${secretsRepoPath}";
      };
    in
      result
  '';

  # Create scripts as a record to be used in activation scripts
  activationScripts = {
    # Setup script - kept as shell script for running Git commands
    setupRepo = ''
            # Ensure git is in the path
            export PATH="${pkgs.git}/bin:$PATH"

            echo "Setting up secrets repository at ${secretsRepoPath}"

            # Create directory if it doesn't exist
            mkdir -p "${secretsRepoPath}"

            # Initialize git repo if not already initialized
            if [ ! -d "${secretsRepoPath}/.git" ]; then
              echo "Initializing git repository"
              cd "${secretsRepoPath}" && git init

              # Create .gitignore file
              echo "# Ignore decrypted secrets" > "${secretsRepoPath}/.gitignore"
              echo "*.key" >> "${secretsRepoPath}/.gitignore"
              echo "*.dec" >> "${secretsRepoPath}/.gitignore"

              git add .gitignore
              git config --local user.email "noreply@aloshy.ai"
              git config --local user.name "Nix Secret Manager"
              git commit -m "Initial commit"
            else
              echo "Git repository already initialized"
            fi

            # Create secrets.nix if it doesn't exist
            if [ ! -f "${secretsRepoPath}/secrets.nix" ]; then
              echo "Creating secrets.nix"
              cat > "${secretsRepoPath}/secrets.nix" << 'EOF'
      let
        # Add your public keys here as strings
        publicKeys = {
          ${cfg.recipientName} = "${cfg.publicKey}";
        };

        # Map recipient names to their public keys
        recipients = builtins.attrValues publicKeys;
      in
      {
        inherit publicKeys recipients;
      }
      EOF
              git -C "${secretsRepoPath}" add secrets.nix
              git -C "${secretsRepoPath}" commit -m "Add secrets.nix"
            fi

            # Add remote if specified and not already added
            if [ ! -z "${cfg.remoteUrl}" ]; then
              if ! git -C "${secretsRepoPath}" remote | grep -q "origin"; then
                echo "Adding remote: ${cfg.remoteUrl}"
                git -C "${secretsRepoPath}" remote add origin "${cfg.remoteUrl}"
              else
                # Update remote URL if different
                CURRENT_URL=$(git -C "${secretsRepoPath}" remote get-url origin 2>/dev/null || echo "")
                if [ "$CURRENT_URL" != "${cfg.remoteUrl}" ]; then
                  echo "Updating remote URL to: ${cfg.remoteUrl}"
                  git -C "${secretsRepoPath}" remote set-url origin "${cfg.remoteUrl}"
                fi
              fi
            fi

            echo "Secret repository setup complete"
    '';

    # Pull script - Git operations require shell script
    pullRepo = ''
      # Ensure git is in the path
      export PATH="${pkgs.git}/bin:$PATH"

      # Check if repo exists
      if [ ! -d "${secretsRepoPath}/.git" ]; then
        echo "Secrets repository does not exist at ${secretsRepoPath}"
        exit 0
      fi

      # Skip if no remote URL is configured
      if [ -z "${cfg.remoteUrl}" ]; then
        echo "No remote URL configured, skipping pull"
        exit 0
      fi

      echo "Pulling secrets repository from ${cfg.remoteUrl}"

      cd "${secretsRepoPath}" || exit 0

      # Check if there are local changes
      if [ "$(git status --porcelain | wc -l)" -ne 0 ]; then
        if [ "${cfg.pullMode}" = "safe" ]; then
          echo "Local changes detected, aborting pull in safe mode"
          exit 0
        elif [ "${cfg.pullMode}" = "stash" ]; then
          echo "Stashing local changes"
          git stash
          git pull --ff-only
          git stash pop || echo "Warning: Failed to pop stash, there may be conflicts"
        elif [ "${cfg.pullMode}" = "force" ]; then
          echo "Forcing pull and discarding local changes"
          git fetch
          git reset --hard origin/main || git reset --hard origin/master
        fi
      else
        # No changes, safe to pull
        git pull --ff-only
      fi

      echo "Secrets repository updated"
    '';

    # Export script - decryption requires age command
    exportSecrets = ''
      # Create export directory with secure permissions
      mkdir -p "${exportPath}"
      chmod 700 "${exportPath}"

      # Check if repo exists
      if [ ! -d "${secretsRepoPath}" ]; then
        echo "Secrets repository does not exist at ${secretsRepoPath}"
        exit 0
      fi

      # Check if secrets.nix exists
      if [ ! -f "${secretsRepoPath}/secrets.nix" ]; then
        echo "secrets.nix not found in repository"
        exit 0
      fi

      # Check if secrets list is empty to avoid hanging
      # Try different patterns to match secrets, based on the format of secrets.nix
      SECRETS=""
      # Try pattern for format: { publicKeys.recipientName = "key"; }
      if [ -z "$SECRETS" ]; then
        SECRETS=$(grep -o "\"${cfg.recipientName}\"" "${secretsRepoPath}/secrets.nix" 2>/dev/null | wc -l)
        if [ "$SECRETS" -gt 0 ]; then
          # Just get the list of encrypted files
          SECRETS=$(find "${secretsRepoPath}" -name "*.age" -type f | sed 's|.*/||' | sed 's/\.age$//')
        fi
      fi
      # Try older format: secrets.name
      if [ -z "$SECRETS" ]; then
        SECRETS=$(grep -o 'secrets\.[a-zA-Z0-9_-]*' "${secretsRepoPath}/secrets.nix" 2>/dev/null | sed 's/secrets\.//' | sort | uniq)
      fi
      # Try newer format looking directly for .age files
      if [ -z "$SECRETS" ]; then
        SECRETS=$(find "${secretsRepoPath}" -name "*.age" -type f | sed 's|.*/||' | sed 's/\.age$//')
      fi

      if [ -z "$SECRETS" ]; then
        echo "No secrets found in repository"
        exit 0
      fi

      # Create a test file to verify permissions
      touch "${exportPath}/.test" && rm "${exportPath}/.test" || {
        echo "WARNING: Cannot write to ${exportPath}. Skipping secret export."
        exit 0
      }

      echo "Exporting secrets to ${exportPath}"

      # Export each secret
      for SECRET in $SECRETS; do
        SECRET_FILE="${secretsRepoPath}/$SECRET.age"

        if [ ! -f "$SECRET_FILE" ]; then
          echo "Warning: Secret file not found: $SECRET.age"
          continue
        fi

        # Normalize secret name
        NORMALIZED_SECRET=$(echo "$SECRET" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
        OUTPUT_FILE="${exportPath}/$NORMALIZED_SECRET"

        # Skip decryption if identity file doesn't exist
        if [ ! -f "${identityFile}" ]; then
          echo "Warning: Identity file not found at ${identityFile}"
          echo "Skipping decryption of $SECRET.age"
          continue
        fi

        # Decrypt and save the secret with a time limit to avoid hanging
        echo "Exporting secret: $NORMALIZED_SECRET"
        # Increased timeout to 20 seconds
        ${pkgs.age}/bin/age -d -i "${identityFile}" "$SECRET_FILE" > "$OUTPUT_FILE" 2>/dev/null || {
          echo "Failed to decrypt secret: $SECRET.age"
          continue
        }

        # Set secure permissions
        chmod 600 "$OUTPUT_FILE"
      done

      echo "Secret export complete"
      exit 0  # Ensure we always exit cleanly
    '';

    # Wrap the export script in a timeout
    timedExportSecrets = ''
            # Ensure git is in the path
            export PATH="${pkgs.git}/bin:$PATH"

            # Check for identity file early
            if [ ! -f "${identityFile}" ]; then
              echo "Warning: Identity file not found at ${identityFile}"
              echo "Skipping secrets export"
              exit 0
            fi

            # Write export script to a temporary file
            EXPORT_SCRIPT=$(mktemp)
            chmod +x "$EXPORT_SCRIPT"

            # Write the script content
            cat > "$EXPORT_SCRIPT" << 'EOF'
            ${activationScripts.exportSecrets}
      EOF

            # Run the script with a timeout
            ${pkgs.coreutils}/bin/timeout 30 "$EXPORT_SCRIPT" || {
              echo "Warning: Secrets export timed out after 30 seconds"
              exit 0
            }

            # Clean up
            rm -f "$EXPORT_SCRIPT"
    '';
  };

  # Create a Nix command for adding secrets - simplified
  addSecretCommand = pkgs.writeShellScriptBin "add-secret" ''
    #!/usr/bin/env bash
    if [ $# -lt 1 ]; then
      echo "Usage: secrets-add SECRET_NAME [SECRET_VALUE]"
      echo "If SECRET_VALUE is not provided, you will be prompted for it."
      exit 1
    fi

    SECRET_NAME="$1"
    SECRET_VALUE="$2"

    # If value not provided, prompt for it
    if [ -z "$SECRET_VALUE" ]; then
      echo -n "Enter value for secret $SECRET_NAME: "
      read -s SECRET_VALUE
      echo  # Add newline after hidden input
    fi

    # Call the Nix function directly
    nix-build ~/.config/nix/add-secret.nix --arg name "\"$SECRET_NAME\"" --arg value "\"$SECRET_VALUE\""
  '';

  # Create a Nix command for deleting secrets - simplified
  deleteSecretCommand = pkgs.writeShellScriptBin "delete-secret" ''
    #!/usr/bin/env bash
    if [ $# -ne 1 ]; then
      echo "Usage: secrets-delete SECRET_NAME"
      exit 1
    fi

    SECRET_NAME="$1"

    # Call the Nix function directly
    nix-build ~/.config/nix/delete-secret.nix --arg name "\"$SECRET_NAME\"" | bash
  '';

  # Create a Nix command for listing secrets - simplified
  listSecretsCommand = pkgs.writeShellScriptBin "list-secrets" ''
    #!/usr/bin/env bash

    # Call the Nix function directly
    nix-build ~/.config/nix/list-secrets.nix | bash
  '';
in {
  options.services.secrets-manager = {
    enable = mkEnableOption "Pure Nix secrets management system";

    secretsRepoPath = mkOption {
      type = types.str;
      description = "Path to the nix-secrets repository";
      default = "${config.home.homeDirectory}/aloshy-ai/nix-secrets";
    };

    publicKey = mkOption {
      type = types.str;
      description = "Public key to use for encrypting secrets";
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMn4QR7tS9Ctt9Jve4WqFMsBQMLu6mIgv4ESOURpwZI";
      example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMn4QR7tS9Ctt9Jve4WqFMsBQMLu6mIgv4ESOURpwZI";
    };

    recipientName = mkOption {
      type = types.str;
      description = "Name of the recipient in secrets.nix";
      default = "aloshy";
      example = "aloshy";
    };

    setupOnActivation = mkOption {
      type = types.bool;
      description = "Whether to set up the secrets repository during activation";
      default = true;
    };

    remoteUrl = mkOption {
      type = types.str;
      description = "URL of the remote Git repository for secrets";
      default = "";
      example = "https://github.com/user/nix-secrets.git";
    };

    pullOnRebuild = mkOption {
      type = types.bool;
      description = "Whether to pull the secrets repository during rebuild";
      default = true;
    };

    pullMode = mkOption {
      type = types.enum ["safe" "stash" "force"];
      description = ''
        How to handle local changes when pulling:
        - safe: Abort if there are local changes
        - stash: Stash local changes, pull, then apply stash
        - force: Discard local changes and force pull
      '';
      default = "safe";
    };

    exportSecrets = mkOption {
      type = types.bool;
      description = "Whether to export decrypted secrets to a directory";
      default = true;
    };

    exportPath = mkOption {
      type = types.str;
      description = "Path to export decrypted secrets to";
      default = "${config.home.homeDirectory}/.secrets";
    };

    identityFile = mkOption {
      type = types.str;
      description = "Path to the identity file (private key) for decryption";
      default = "${config.home.homeDirectory}/.ssh/id_ed25519";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      age
      git
      secretsHelper
      # Rename the commands to avoid collisions
      (pkgs.runCommand "secrets-commands" {} ''
        mkdir -p $out/bin
        ln -s ${addSecretCommand}/bin/add-secret $out/bin/secrets-add
        ln -s ${deleteSecretCommand}/bin/delete-secret $out/bin/secrets-delete
        ln -s ${listSecretsCommand}/bin/list-secrets $out/bin/secrets-list
      '')
    ];

    # Add Git to the session PATH
    home.sessionPath = ["${pkgs.git}/bin"];

    # Set up the secrets repository during activation if requested
    home.activation.setupSecretsRepo = mkIf cfg.setupOnActivation ''
      $DRY_RUN_CMD ${activationScripts.setupRepo}
    '';

    # Pull the secrets repository during activation if requested
    home.activation.pullSecretsRepo = mkIf (cfg.enable && cfg.pullOnRebuild) ''
      $DRY_RUN_CMD ${activationScripts.pullRepo}
    '';

    # Export decrypted secrets during activation if requested
    home.activation.exportSecrets = mkIf (cfg.enable && cfg.exportSecrets) ''
      $DRY_RUN_CMD ${activationScripts.timedExportSecrets}
    '';

    # Copy the Nix expressions to the user's config directory so they can be used directly
    home.file.".config/nix/add-secret.nix".text = addSecretFunction;
    home.file.".config/nix/delete-secret.nix".text = deleteSecretFunction;
    home.file.".config/nix/list-secrets.nix".text = listSecretsFunction;
  };
}
