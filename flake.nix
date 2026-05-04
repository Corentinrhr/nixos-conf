{
  description = "NixOS 25.11 — Gaming + AI workstation, AMD GPU, dual-boot Windows 11";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbVQh5ZPmF2xKQ2r9FzYv6J9c="
      "nix-community.cachix.org-1:mB9FSh9qf2dde0enFANjS37dphqGW/ovD17dBuej"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
      ];
    };
  };
}