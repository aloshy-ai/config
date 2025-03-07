{
  description = "My Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs = inputs:
  # This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
  # directly unless you explicitly need a feature of `lib`.
  let
    lib = inputs.snowfall-lib.mkLib {
      # You must pass in both your flake's inputs and the root directory of
      # your flake.
      inherit inputs;
      src = ./.;

      snowfall = {
        # Tell Snowfall Lib to look in the `./nix/` directory for your
        # Nix files.
        root = ./nix;

        namespace = "ai.aloshy";
        meta = {
          # Your flake's preferred name in the flake registry.
          name = "config";
          # A pretty name for your flake.
          title = "aloshy.🅰🅸 | Config";
        };
      };
    };
  in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
        nix-vscode-extensions.overlays.default
      ];

      # Add modules to all Darwin systems.
      systems.modules.darwin = with inputs; [
        mac-app-util.darwinModules.default
        lix-module.nixosModules.default
        nix-homebrew.darwinModules.nix-homebrew
      ];

      # Add modules to all NixOS systems.
      systems.modules.nixos = with inputs; [
        nixos-generators.nixosModules.all-formats
        lix-module.nixosModules.default
      ];

      # Add modules to all homes.
      homes.modules = with inputs; [
      ];

      homes.users.aloshy.modules = with inputs; [
        mac-app-util.homeManagerModules.default
      ];

      outputs-builder = channels: {formatter = channels.nixpkgs.alejandra;};
    };
}
