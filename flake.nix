{
  description = "Kosmos — NixOS configurations for NUC and WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    nixos-wsl,
    disko,
    agenix,
    nix-index-database,
    home-manager,
    fenix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    pkgsUnstable = import nixpkgs-unstable {inherit system;};
  in {
    checks.${system}.shell-tests =
      pkgs.runCommand "kosmos-shell-tests" {
        nativeBuildInputs = with pkgs; [
          bash
          coreutils
          gawk
          gnused
          jq
          python3
          shellcheck
        ];
      } ''
        shellcheck \
          ${./scripts/ttal-tmux-project-picker} \
          ${./scripts/ttal-wezterm-projects} \
          ${./tests/temenos-env-test} \
          ${./tests/ttal-tmux-project-picker-test} \
          ${./tests/temenos-ca-test} \
          ${./tests/tmux-tmpdir-test} \
          ${./tests/orga-cli-service-test} \
          ${./tests/ttal-wezterm-projects-test}
        KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-tmux-project-picker-test}
        KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-ca-test}
        KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
        KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-tmpdir-test}
        KOSMOS_REPO_ROOT=${./.} bash ${./tests/orga-cli-service-test}
        KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-wezterm-projects-test}
        touch $out
      '';

    nixosConfigurations.kosmos = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit pkgsUnstable;
      };
      modules = [
        disko.nixosModules.disko
        agenix.nixosModules.default
        nix-index-database.nixosModules.default
        ./hosts/kosmos
      ];
    };

    nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit agenix pkgsUnstable fenix;
      };
      modules = [
        nixos-wsl.nixosModules.default
        agenix.nixosModules.default
        nix-index-database.nixosModules.default
        home-manager.nixosModules.home-manager
        ./hosts/wsl
      ];
    };

    diskoConfigurations.nixos = import ./disko-config.nix;

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        nix
        statix
        nixd
        lefthook
        shellcheck
      ];
    };
  };
}
