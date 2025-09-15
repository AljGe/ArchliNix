{
  description = "My Declarative Home Environment on Arch Linux";

  # Define all external dependencies here.
  inputs = {
    # The primary Nix package collection.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # The Home Manager tool.
    home-manager = {
      url = "github:nix-community/home-manager";
      # This line ensures Home Manager uses the same version of nixpkgs
      # that is defined above, preventing version conflicts.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # NUR for firefox add-ons (rycee) and other community packages
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Define what this flake builds.
  outputs = {
    self,
    nixpkgs,
    home-manager,
    sops-nix,
    nur,
    ...
  }: {
    # Define a Home Manager configuration for a specific user and host.
    # Using a unique name like "username@hostname" allows for managing
    # multiple configurations from the same flake.
    homeConfigurations."archliNix" = home-manager.lib.homeManagerConfiguration {
      # Pass the nixpkgs collection to Home Manager.
      # The architecture must match the host system.
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      # Specify the main module file for this configuration.
      modules = [
        sops-nix.homeManagerModule
        # Enable NUR overlay so pkgs.nur.repos.rycee.firefox-addons is available
        ({
          config,
          pkgs,
          ...
        }: {
          nixpkgs.overlays = [nur.overlays.default];
        })
        ./home.nix
      ];
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
