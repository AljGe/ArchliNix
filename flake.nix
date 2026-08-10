{
  description = "My Declarative Home Environment on Arch Linux";

  # Define all external dependencies here.
  inputs = {
    # Stable channel - primary source for most packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # Unstable channel - for bleeding edge packages
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # The Home Manager tool (pinned to match nixpkgs release)
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # This line ensures Home Manager uses the same version of nixpkgs
      # that is defined above, preventing version conflicts.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Prebuilt nix-index database for fast command-not-found suggestions
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Skills collection for the pi coding agent (pinned, not a Nix flake)
    pi-skills = {
      url = "github:badlogic/pi-skills";
      flake = false;
    };
  };
  # Define what this flake builds.
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      sops-nix,
      nix-index-database,
      pi-skills,
      ...
    }:
    let
      # Single Home Manager evaluation shared by the homeConfigurations output
      # and the pi-hpc-bundle package, so the bundle always mirrors the live
      # config (model tiers, thinking levels, skills, aliases).
      hmConfig = home-manager.lib.homeManagerConfiguration {
        # Pass the nixpkgs collection to Home Manager.
        # The architecture must match the host system.
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        # Pass unstable pkgs to modules for selective bleeding-edge packages
        extraSpecialArgs = {
          pkgs-unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
          pi-skills = pi-skills;
        };
        # Specify the main module file for this configuration.
        modules = [
          sops-nix.homeManagerModule
          nix-index-database.homeModules.nix-index
          ./home.nix
        ];
      };
    in
    {
      # Define a Home Manager configuration for a specific user and host.
      # Using a unique name like "username@hostname" allows for managing
      # multiple configurations from the same flake.
      homeConfigurations."archliNix" = hmConfig;

      # Self-contained pi bundle for an HPC login node (no Nix, no root):
      # agent config + skills + rc + installer. See modules/pi-hpc-bundle.nix
      # and hpc/README.md; ship it with ./hpc/sync-to-hpc.sh.
      packages.x86_64-linux.pi-hpc-bundle = import ./modules/pi-hpc-bundle.nix {
        inherit (nixpkgs) lib;
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        hmConfig = hmConfig;
      };
    };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cache.garnix.io"
      "https://devenv.cachix.org"
      "https://numtide.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "devenv.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo="
      "numtide.cachix.org-1:2ps4FhNIRZrg4n/7P+90E0SZL2B3enJnxa6Q/Q/Pgqc="
    ];
  };
}
