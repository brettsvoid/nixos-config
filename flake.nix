{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ambxst = {
      url = "github:Axenide/Ambxst";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ambxst, ... }: {
    nixosConfigurations = {
      brett-msi-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/msi-laptop/configuration.nix
          home-manager.nixosModules.home-manager
          ambxst.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.brett = import ./home/home.nix;
          }
        ];
      };

      # Future machines go here:
      # brett-desktop = nixpkgs.lib.nixosSystem { ... };
    };
  };
}
