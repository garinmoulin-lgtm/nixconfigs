# Change "garinh" to your username, always, before installing.
{
  inputs = {
    lanzaboote = {
        url = "github:nix-community/lanzaboote";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    catppuccin.url = "github:catppuccin/nix";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    quickshell = {
        url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, catppuccin, home-manager, chaotic, lanzaboote, quickshell, apple-fonts, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        # Not using chaotic.nixosModules.default: its nyx-registry module sets the
        # renamed nix.nixPath option and triggers an eval warning on unstable.
        # Swap back once chaotic-cx/nyx#3037 is merged.
        chaotic.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.garinh = {
            imports = [ inputs.catppuccin.homeModules.catppuccin ./home.nix ];
            catppuccin.enable = true;
            catppuccin.autoEnable = true;
            home.stateVersion = "26.05";
          };
        }
      ];
    };
  };
}
