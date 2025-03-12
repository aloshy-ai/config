{
  description = "Plus Ultra";

  inputs = {
    # NixPkgs (nixos-22.05)
    nixpkgs.url =
      "github:nixos/nixpkgs/nixos-22.05";

    # NixPkgs Unstable (nixos-unstable)
    unstable.url =
      "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager (release-22.05)
    home-manager.url =
      "github:nix-community/home-manager/release-22.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # macOS Support (master)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Generate System Images
    nixos-generators.url =
      "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Snowfall Lib
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

    # Snowfall Flake
    snowfall-flake.url = "github:snowfallorg/flake";
    snowfall-flake.inputs.nixpkgs.follows = "unstable";

    # Comma
    comma.url =
      "github:nix-community/comma";
    comma.inputs.nixpkgs.follows = "unstable";

    # System Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "unstable";

    # Run unpatched dynamically compiled binaries
    nix-ld.url = "github:Mic92/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "unstable";

    # Neovim
    neovim.url = "github:jakehamilton/neovim";
    neovim.inputs.nixpkgs.follows = "unstable";
    neovim.inputs.snowfall-lib.follows = "snowfall-lib";

    # Discord Replugged
    replugged.url = "github:LunNova/replugged-nix-flake";
    replugged.inputs.nixpkgs.follows = "unstable";

    # Discord Replugged plugins / themes
    discord-tweaks = {
      url = "github:NurMarvin/discord-tweaks";
      flake = false;
    };
    discord-nord-theme = {
      url = "github:DapperCore/NordCord";
      flake = false;
    };
  };

  outputs = inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;
      };
    in
    lib.mkFlake {
      overlay-package-namespace = "plusultra";

      channels-config.allowUnfree = true;

      overlays = with inputs; [
        neovim.overlays."nixpkgs/neovim"
        snowfall-flake.overlays."nixpkgs/flake"
      ];

      systems.modules = with inputs; [
        home-manager.nixosModules.home-manager
        nix-ld.nixosModules.nix-ld
      ];

      systems.hosts.jasper.modules = with inputs; [
        nixos-hardware.nixosModules.framework
      ];

      deploy = lib.mkDeploy { inherit (inputs) self; };
    };
}
