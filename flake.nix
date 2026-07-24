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
    kepos-neo = {
      url = "github:tta-lab/kepos-neo/b4c6f5cafa1877a082d0dfead83dfb32c14e024f";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
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
    kepos-neo,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    pkgsUnstable = import nixpkgs-unstable {inherit system;};
  in {
    checks.${system} = {
      shell-tests =
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
            ${./scripts/cloudflared-ingress-smoke} \
            ${./scripts/devops-gate-status} \
            ${./scripts/forgejo-https-git-smoke} \
            ${./scripts/forgejo-k8s-pull-secret-smoke} \
            ${./scripts/ttal-tmux-project-picker} \
            ${./scripts/wsl-devops-smoke} \
            ${./tests/temenos-env-test} \
            ${./tests/ttal-tmux-project-picker-test} \
            ${./tests/temenos-ca-test} \
            ${./tests/cloudflared-ingress-smoke-test} \
            ${./tests/tmux-tmpdir-test} \
            ${./tests/tmux-copy-mode-test} \
            ${./tests/devops-gate-status-test} \
            ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-tmux-project-picker-test}
          KOSMOS_REPO_ROOT=${./.} ${pkgs.python3}/bin/python3 ${./tests/test_sync_projects_auth.py}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-ca-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/cloudflared-ingress-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-tmpdir-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-copy-mode-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/devops-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/orga-cli-service-test}
          touch $out
        '';

      kepos-tunnel-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            agenix.nixosModules.default
            ./modules/wsl/kepos-tunnel.nix
            (_: {
              system.stateVersion = "25.05";
              kosmos.wsl.keposTunnel.enable = true;
              services.cloudflared.tunnels.kepos.ingress."test.guion.io" = "http://127.0.0.1:8080";
            })
          ];
        };
        cfg = eval.config;
        tunnel = cfg.services.cloudflared.tunnels.kepos;
      in
        assert cfg.services.cloudflared.enable;
        assert tunnel.default == "http_status:404";
        assert tunnel.credentialsFile == cfg.age.secrets.cloudflared-kepos-credentials.path;
        assert tunnel.ingress."test.guion.io" == "http://127.0.0.1:8080";
        assert cfg.systemd.services.cloudflared-tunnel-kepos.environment.TUNNEL_TRANSPORT_PROTOCOL == "http2";
          pkgs.runCommand "kepos-tunnel-module-check" {} "touch $out";

      forgejo-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/wsl/forgejo.nix
            (_: {
              system.stateVersion = "25.05";
              kosmos.wsl.forgejo.enable = true;
            })
          ];
        };
        cfg = eval.config;
        inherit (cfg.services) forgejo;
      in
        assert forgejo.enable;
        assert forgejo.database.type == "sqlite3";
        assert forgejo.database.path == "/var/lib/forgejo/data/forgejo.db";
        assert forgejo.settings.server.ROOT_URL == "https://git.guion.io/";
        assert forgejo.settings.server.HTTP_ADDR == "127.0.0.1";
        assert forgejo.settings.server.HTTP_PORT == 3000;
        assert forgejo.settings.server.DISABLE_SSH;
        assert forgejo.settings.packages.ENABLED;
        assert forgejo.settings.service.DISABLE_REGISTRATION;
        assert forgejo.settings.service.REQUIRE_SIGNIN_VIEW;
        assert !forgejo.settings.actions.ENABLED;
          pkgs.runCommand "kosmos-forgejo-module-check" {} ''
            touch $out
          '';
    };

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
        inherit agenix fenix kepos-neo nixpkgs-unstable pkgsUnstable;
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
