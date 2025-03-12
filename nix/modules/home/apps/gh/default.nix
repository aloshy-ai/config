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
  programs.gh = {
    enable = true;
    # GitHub CLI configuration
    settings = {
      # Using environment variable for authentication
      git_protocol = "https";
      prompt = "enabled";
    };
  };

  # Create a profile script that will be sourced on shell startup
  home.file.".profile.d/github-token.sh" = {
    executable = true;
    text = ''
      # GitHub token setup

      # Unset any existing token to avoid using invalid tokens
      unset GITHUB_TOKEN

      # Try to get token from keychain first (most reliable)
      if command -v gh >/dev/null 2>&1; then
        if TOKEN=$(gh auth token 2>/dev/null); then
          if [ -n "$TOKEN" ]; then
            export GITHUB_TOKEN="$TOKEN"
          fi
        fi
      fi

      # If no token from keychain, try secrets-helper as fallback
      if [ -z "''${GITHUB_TOKEN:-}" ] && command -v secrets-helper >/dev/null 2>&1; then
        TOKEN=$(secrets-helper show GITHUB_TOKEN 2>/dev/null || echo "")
        if [ -n "$TOKEN" ]; then
          export GITHUB_TOKEN="$TOKEN"
        fi
      fi
    '';
  };

  # Ensure the profile directory exists
  home.file.".profile.d/.keep" = {
    text = "";
  };

  # Source all scripts in .profile.d directory in shell config
  programs.zsh.initExtra = ''
    # Source all files in ~/.profile.d
    if [ -d "$HOME/.profile.d" ]; then
      for file in $HOME/.profile.d/*.sh; do
        if [ -r "$file" ]; then
          source "$file"
        fi
      done
      unset file
    fi
  '';

  programs.bash.initExtra = ''
    # Source all files in ~/.profile.d
    if [ -d "$HOME/.profile.d" ]; then
      for file in $HOME/.profile.d/*.sh; do
        if [ -r "$file" ]; then
          source "$file"
        fi
      done
      unset file
    fi
  '';
}
