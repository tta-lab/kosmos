{
  description = "Kosmos — NixOS configuration for Intel NUC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, disko, agenix, nix-index-database, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    nixosConfigurations.kosmos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        disko.nixosModules.disko
        agenix.nixosModules.default
        nix-index-database.nixosModules.default
        ./configuration.nix
      ];
    };

    diskoConfigurations.nixos = import ./disko-config.nix;

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        nix
        statix
        nixd
      ];
    };
  };
}
