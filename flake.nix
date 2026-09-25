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
    waybar = {
        url = "github:Alexays/Waybar";
        inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
        
    };

  };

  outputs = { self, nixpkgs, catppuccin, home-manager, waybar, chaotic, lanzaboote, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
      {
          nixpkgs.overlays = [
            waybar.overlays.default
            (final: prev: {
              waybar = prev.waybar.overrideAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [ prev.modemmanager ];
                mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dcava=disabled" "-Dsystemd=disabled" ];
                env.NIX_CFLAGS_COMPILE = "-march=native -O3";
                doInstallCheck = false;
              });
            })
          ];
        }
        ./configuration.nix
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
