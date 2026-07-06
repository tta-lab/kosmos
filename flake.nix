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
            woodpecker-cli
          ];
        } ''
          shellcheck \
            ${./scripts/cloudflared-ingress-smoke} \
            ${./scripts/dagger-local-registry-smoke} \
            ${./scripts/dagger-large-registry-smoke} \
            ${./scripts/dagger-engine-config-smoke} \
            ${./scripts/dagger-engine-isolation-smoke} \
            ${./scripts/dagger-unix-socket-smoke} \
            ${./scripts/data-disk-preflight} \
            ${./scripts/devops-gate-status} \
            ${./scripts/forgejo-backup-replicate} \
            ${./scripts/forgejo-backup-smoke} \
            ${./scripts/forgejo-cutover-preflight} \
            ${./scripts/forgejo-dump-restore-smoke} \
            ${./scripts/forgejo-https-git-smoke} \
            ${./scripts/forgejo-k8s-pull-secret-smoke} \
            ${./scripts/forgejo-migration-dry-run} \
            ${./scripts/forgejo-restore-smoke} \
            ${./scripts/ttal-tmux-project-picker} \
            ${./scripts/ttal-wezterm-projects} \
            ${./scripts/woodpecker-dagger-job-smoke} \
            ${./scripts/woodpecker-preflight} \
            ${./scripts/wsl-devops-smoke} \
            ${./tests/temenos-env-test} \
            ${./tests/ttal-tmux-project-picker-test} \
            ${./tests/temenos-ca-test} \
            ${./tests/cloudflared-ingress-smoke-test} \
            ${./tests/dagger-large-registry-smoke-test} \
            ${./tests/dagger-engine-config-smoke-test} \
            ${./tests/dagger-engine-isolation-smoke-test} \
            ${./tests/data-disk-preflight-test} \
            ${./tests/forgejo-backup-smoke-test} \
            ${./tests/forgejo-dump-restore-smoke-test} \
            ${./tests/forgejo-restore-smoke-test} \
            ${./tests/tmux-tmpdir-test} \
            ${./tests/tmux-copy-mode-test} \
            ${./tests/devops-gate-status-test} \
            ${./tests/orga-cli-service-test} \
            ${./tests/ttal-wezterm-projects-test}
          WOODPECKER_DISABLE_UPDATE_CHECK=true woodpecker-cli lint --strict ${./fixtures/woodpecker/dagger-unix-socket-smoke.yml}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-tmux-project-picker-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-ca-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/cloudflared-ingress-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/dagger-large-registry-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/dagger-engine-config-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/dagger-engine-isolation-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/data-disk-preflight-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-backup-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-dump-restore-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-restore-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-tmpdir-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-copy-mode-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/devops-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-wezterm-projects-test}
          touch $out
        '';

      woodpecker-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            agenix.nixosModules.default
            ./modules/wsl/woodpecker.nix
            ({pkgs, ...}: {
              system.stateVersion = "25.05";
              kosmos.wsl.woodpecker = {
                enable = true;
                serverEnvironmentFile = pkgs.writeText "woodpecker-server.env" ''
                  WOODPECKER_AGENT_SECRET=test
                  WOODPECKER_FORGEJO_CLIENT=test
                  WOODPECKER_FORGEJO_SECRET=test
                '';
                agentEnvironmentFile = pkgs.writeText "woodpecker-agent.env" ''
                  WOODPECKER_AGENT_SECRET=test
                '';
              };
            })
          ];
        };
        cfg = eval.config;
        agent = cfg.services.woodpecker-agents.agents.wsl-podman;
        agentUnit = cfg.systemd.services.woodpecker-agent-wsl-podman;
        server = cfg.services.woodpecker-server;
        has = value: list: builtins.elem value list;
      in
        assert server.enable;
        assert server.environment.WOODPECKER_ENVIRONMENT == "_EXPERIMENTAL_DAGGER_RUNNER_HOST:unix:///run/dagger/engine.sock";
        assert agent.enable;
        assert agent.environment.DOCKER_HOST == "unix:///run/podman/podman.sock";
        assert agent.environment.WOODPECKER_BACKEND_DOCKER_VOLUMES == "/run/dagger:/run/dagger";
        assert has "podman.socket" agentUnit.after;
        assert has "podman-dagger-engine.service" agentUnit.after;
        assert has "forgejo-internal-registry-proxy.service" agentUnit.after;
        assert has "forgejo-internal-registry-proxy.service" agentUnit.wants;
          pkgs.runCommand "kosmos-woodpecker-module-check" {} ''
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
        inherit agenix nixpkgs-unstable pkgsUnstable fenix;
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
