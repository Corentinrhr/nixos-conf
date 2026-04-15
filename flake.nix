{
  description = "NixOS 25.11 stable AMD system with GNOME, CachyOS kernel, systemd-boot first, Lanzaboote later, and Flatpak";

  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    accept-flake-config = true;
    extra-substituters = [
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbVQh5ZPmF2xKQ2r9FzYv6J9c="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

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
              nix-cachyos-kernel.overlays.pinned
            ];
          })

          ./hardware-configuration.nix
          ./configuration.nix

          lanzaboote.nixosModules.lanzaboote
          nix-flatpak.nixosModules.nix-flatpak
        ];
      };
    };
}