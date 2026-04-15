{
  description = "NixOS 25.11 stable AMD system with GNOME, CachyOS kernel, Lanzaboote & Flatpak";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  outputs = { self, nixpkgs, lanzaboote, nix-cachyos-kernel, nix-flatpak, ... }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ({ ... }: {
            nixpkgs.overlays = [
              nix-cachyos-kernel.overlays.default
            ];
          })

          ./hardware-configuration.nix
          ./modules/configuration.nix

          lanzaboote.nixosModules.lanzaboote
          nix-flatpak.nixosModules.nix-flatpak
        ];
      };
    };
}