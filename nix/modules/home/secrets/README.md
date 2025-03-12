# Pure Nix Secrets Management

This module provides a pure Nix-based approach to manage encrypted secrets using age encryption, with automatic syncing and exporting during system rebuilds.

## Overview

The secrets management system is designed to:

- Store encrypted secrets in a separate Git repository
- Use age encryption with SSH keys for security
- Provide Nix functions for adding, updating, and deleting secrets
- Maximize the use of pure Nix expressions and derivations
- Pull the latest secrets during system rebuilds
- Export decrypted secrets for use in your system

## Design Philosophy

This module follows a "Nix-first" approach:

1. All configuration is expressed in pure Nix
2. Secret encryption happens within Nix derivations
3. Functions are provided as Nix expressions
4. The system is integrated with your rebuild workflow

## Setup

To set up the secrets management system:

1. Enable the module in your home configuration:

```nix
{
  services.secrets-manager = {
    enable = true;
    # Remote repository URL (optional, for syncing)
    remoteUrl = "https://github.com/user/nix-secrets.git";
    # Path to your SSH key for decryption
    identityFile = "~/.ssh/id_ed25519";
    # Where to export decrypted secrets
    exportPath = "~/.secrets";
  };
}
```

2. Build and activate your Home Manager configuration:

```bash
home-manager switch
```

## Git Repository Integration

The system can integrate with a remote Git repository:

- During setup, it will initialize a local repository if one doesn't exist
- If a `remoteUrl` is provided, it will be added as a remote
- During rebuilds, it can pull the latest changes based on your configuration

Configure the pull behavior:

```nix
{
  services.secrets-manager = {
    # Whether to pull during rebuilds
    pullOnRebuild = true;
    # How to handle local changes: "safe", "stash", or "force"
    pullMode = "safe";
  };
}
```

## Exported Secrets

When `exportSecrets` is enabled (default), all secrets are automatically:

1. Decrypted using your private key
2. Exported to the configured `exportPath` (default: `~/.secrets`)
3. Set with secure permissions (700 for directory, 600 for files)

This makes secrets available for your shell scripts and applications.

## Usage

### Managing Secrets

Use the command-line tools to manage your secrets:

```bash
# Add a new secret
add-secret SECRET_NAME "SECRET_VALUE"

# List all secrets
list-secrets

# Delete a secret
delete-secret SECRET_NAME
```

### Using Exported Secrets

Access exported secrets using the `secrets-helper` utility:

```bash
# List all available secrets
secrets-helper list

# Get the path to a specific secret
secrets-helper get GITHUB_TOKEN

# View the content of a secret
secrets-helper show GITHUB_TOKEN
```

In your shell scripts:

```bash
# Get a secret value in a script
TOKEN=$(secrets-helper show GITHUB_TOKEN)
curl -H "Authorization: token $TOKEN" https://api.github.com/user
```

### Using Direct Nix Expressions

For a pure Nix workflow, you can use the installed Nix expressions directly:

```bash
# Add a secret
nix-build ~/.config/nix/add-secret.nix --arg name "github-token" --arg value "your-token-here"

# Delete a secret
nix-build ~/.config/nix/delete-secret.nix --arg name "github-token" | bash

# List secrets
nix-build ~/.config/nix/list-secrets.nix | bash
```

## Module Architecture

The module consists of several Nix files:

- `pure.nix`: Core pure functions for secret management
- `operations.nix`: Nix operations for adding, deleting, and listing secrets
- `default.nix`: Home Manager module definition

Each operation follows this pattern:

1. A pure Nix function normalizes the secret name
2. A Nix derivation is created to encrypt the secret
3. The derivation output includes the encrypted file and metadata
4. A minimal wrapper script is generated to install the derivation results

## Implementation Details

### Secret Storage

Secrets are stored in `$HOME/aloshy-ai/nix-secrets` with:

- One encrypted .age file per secret
- A `secrets.nix` file defining the recipient public keys
- Git version control for tracking changes

### Pure Nix Functions

The module leverages Nix's strengths:

- Reproducible builds for secret encryption
- Attribute sets for configuration
- Nix derivations for managing side effects
- Pure functions for data transformation

## Security Considerations

- Secrets are stored encrypted in the repository
- Decrypted secrets are stored with secure permissions (600)
- The export directory has restricted permissions (700)
- SSH agent is used for decryption when available

## Extension Points

You can extend this module by:

1. Adding new operations in `operations.nix`
2. Customizing the Home Manager module options in `default.nix`
3. Creating additional pure Nix functions in `pure.nix` 