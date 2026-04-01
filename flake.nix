{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ambxst = {
      # Pinned: newer versions cause stutter on NVIDIA external monitors
      url = "github:Axenide/Ambxst/59edec9a0430eb2f679697f4a817a1f44ffcfb8b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ambxst, quickshell, ... }: {
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
            home-manager.extraSpecialArgs = { inherit quickshell; };
            home-manager.users.brett = import ./home/home.nix;
          }
        ];
      };

      # Future machines go here:
      # brett-desktop = nixpkgs.lib.nixosSystem { ... };
    };
  };
}
