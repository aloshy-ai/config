{
  description = "My Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-flake = {
      url = "github:snowfallorg/flake";
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-mcp-servers = {
      url = "github:aloshy-ai/nix-mcp-servers";
      inputs.nixpkgs.follows = "nixpkgs";
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

        # Include the secrets directory in the build
        includePaths = [
          ./secrets
        ];

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
        snowfall-flake.overlays.default
      ];

      # Add modules to all Darwin systems.
      systems.modules.darwin = with inputs; [
        home-manager.darwinModules.home-manager
        mac-app-util.darwinModules.default
        lix-module.nixosModules.default
        nix-homebrew.darwinModules.nix-homebrew
      ];

      # Add modules to all NixOS systems.
      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        nixos-generators.nixosModules.all-formats
      ];

      # Add modules to all homes.
      homes.modules = with inputs; [
        nix-mcp-servers.homeModules.default
      ];

      homes.users."aloshy@silicon".modules = with inputs; [
        mac-app-util.homeManagerModules.default
        agenix.homeManagerModules.age
      ];

      deploy = {inherit (inputs) self;};

      checks =
        builtins.mapAttrs (
          system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy
        )
        inputs.deploy-rs.lib;

      outputs-builder = channels: {formatter = channels.nixpkgs.alejandra;};
    }
    // {
      self = inputs.self;
    };
}
