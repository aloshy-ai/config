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
  # All other arguments come from the system system.
  config,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"
  ];

  # Your configuration.
  system.stateVersion = "25.05";

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes"; # You might want to change this in production
  };

  # Basic networking
  networking = {
    hostName = "rpi4";
    wireless.enable = false; # Disable wireless by default
    useDHCP = true;
  };

  # Users configuration
  users.users.root.hashedPassword = ""; # Empty hash allows login with any password initially
  users.mutableUsers = true; # Allow password changes

  # SD image specific settings
  sdImage = {
    compressImage = true;
    imageBaseName = "nixos-rpi4";
  };

  # Hardware configuration
  hardware = {
    enableRedistributableFirmware = true;
    firmware = [pkgs.raspberrypiWirelessFirmware];
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    initrd.availableKernelModules = ["usbhid" "usb_storage"];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };
}
