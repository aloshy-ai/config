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
  # nix.enable = true;
  # nix.distributedBuilds = true;
  # nix.buildMachines = [
  #   {
  #     hostName = "nixos.tail9a6c09.ts.net";
  #     systems = ["aarch64-linux"];
  #     protocol = "ssh";
  #     sshUser = "aloshy";
  #     sshKey = "/Users/aloshy/.ssh/id_ed25519";
  #     # ssh aloshy@nixos.tail9a6c09.ts.net "base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub"
  #     publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCckEzMDNYdUVQcDYrcmFPYnBlSkhIUURDazVLajFta1FuVDMyVXRwVkcgcm9vdEBuaXhvcwo=";
  #     supportedFeatures = ["benchmark" "big-parallel" "kvm"];
  #   }
  # ];
}
