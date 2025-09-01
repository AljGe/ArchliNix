{ description = "My Declarative Home Environment on Arch Linux";

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
  };

  # Define what this flake builds.
  outputs = { self, nixpkgs, home-manager,... }: {
    # Define a Home Manager configuration for a specific user and host.
    # Using a unique name like "username@hostname" allows for managing
    # multiple configurations from the same flake.
    homeConfigurations."archliNix" = home-manager.lib.homeManagerConfiguration {
      # Pass the nixpkgs collection to Home Manager.
      # The architecture must match the host system.
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Specify the main module file for this configuration.
      modules = [./home.nix ];
    };
  };
}
