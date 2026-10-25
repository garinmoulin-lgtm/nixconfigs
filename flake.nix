# Change "garinh" to your username, always, before installing.
{
  inputs = {
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
    # MediaTek MT7927 Bluetooth firmware (see hardware.firmware in configuration.nix).
    # Not a flake, just the repo's files: its firmware extractor, and the ASUS driver
    # release (file name + hash) it currently uses. `nix flake update` follows it.
    mt7927-dkms = {
      url = "github:jetm/mediatek-mt7927-dkms";
      flake = false;
    };
    # Rosé Pine's GTK theme (not in nixpkgs), for the rose-pine theme in home.nix.
    # Also just the repo's files.
    rose-pine-gtk = {
      url = "github:rose-pine/gtk";
      flake = false;
    };
    # Everblush's GTK theme (not in nixpkgs), for the everblush theme in home.nix.
    # Also just the repo's files.
    everblush-gtk = {
      url = "github:Everblush/gtk";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      chaotic,
      lanzaboote,
      quickshell,
      apple-fonts,
      ...
    }@inputs:
    {
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
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.garinh = {
              imports = [
                ./home.nix
              ];
              home.stateVersion = "26.05";
            };
          }
        ];
      };
    };
}
