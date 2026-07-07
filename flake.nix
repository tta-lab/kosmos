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
            ${./scripts/forgejo-k3s-migration} \
            ${./scripts/forgejo-migration-dry-run} \
            ${./scripts/forgejo-restore-smoke} \
            ${./scripts/ttal-tmux-project-picker} \
            ${./scripts/ttal-wezterm-projects} \
            ${./scripts/woodpecker-dagger-job-smoke} \
            ${./scripts/woodpecker-k3s-migration} \
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
            ${./tests/forgejo-k3s-migration-mock-test} \
            ${./tests/forgejo-k3s-migration-test} \
            ${./tests/forgejo-restore-smoke-test} \
            ${./tests/tmux-tmpdir-test} \
            ${./tests/tmux-copy-mode-test} \
            ${./tests/devops-gate-status-test} \
            ${./tests/orga-cli-service-test} \
            ${./tests/ttal-wezterm-projects-test} \
            ${./tests/woodpecker-k3s-migration-test}
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
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-k3s-migration-mock-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-k3s-migration-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-restore-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-tmpdir-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-copy-mode-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/devops-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-wezterm-projects-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/woodpecker-k3s-migration-test}
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
        inherit (cfg.systemd.services) forgejo-internal-registry-proxy;
        has = value: list: builtins.elem value list;
      in
        assert forgejo.enable;
        assert forgejo.database.type == "sqlite3";
        assert forgejo.database.path == "/var/lib/forgejo/data/forgejo.db";
        assert forgejo.dump.enable;
        assert forgejo.dump.backupDir == "/var/backup/forgejo";
        assert forgejo.settings.server.ROOT_URL == "https://git-wsl.guion.io/";
        assert forgejo.settings.server.HTTP_ADDR == "127.0.0.1";
        assert forgejo.settings.server.HTTP_PORT == 3000;
        assert forgejo.settings.server.DISABLE_SSH;
        assert forgejo.settings.packages.ENABLED;
        assert forgejo.settings.service.DISABLE_REGISTRATION;
        assert forgejo.settings.service.REQUIRE_SIGNIN_VIEW;
        assert !forgejo.settings.actions.ENABLED;
        assert has "forgejo.service" forgejo-internal-registry-proxy.after;
        assert has "forgejo.service" forgejo-internal-registry-proxy.wants;
          pkgs.runCommand "kosmos-forgejo-module-check" {} ''
            touch $out
          '';

      data-disk-backup-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/wsl/data-disk.nix
            ./modules/wsl/forgejo.nix
            (_: {
              system.stateVersion = "25.05";
              kosmos.wsl = {
                dataDisk = {
                  enable = true;
                  device = "/dev/disk/by-uuid/bf1ab97f-1d98-4977-89ed-58a8d0098e6c";
                };
                forgejo = {
                  enable = true;
                  backupReplicaDir = "/mnt/nuc-data/forgejo-backups";
                };
              };
            })
          ];
        };
        cfg = eval.config;
        backupService = cfg.systemd.services.forgejo-backup-replicate;
        backupTimer = cfg.systemd.timers.forgejo-backup-replicate;
        dataDisk = cfg.fileSystems."/mnt/nuc-data";
        has = value: list: builtins.elem value list;
      in
        assert dataDisk.device == "/dev/disk/by-uuid/bf1ab97f-1d98-4977-89ed-58a8d0098e6c";
        assert dataDisk.fsType == "ext4";
        assert !dataDisk.neededForBoot;
        assert has "forgejo-dump.service" backupService.after;
        assert has "/mnt/nuc-data/forgejo-backups" backupService.unitConfig.RequiresMountsFor;
        assert backupTimer.timerConfig.OnCalendar == "hourly";
        assert backupTimer.timerConfig.Unit == "forgejo-backup-replicate.service";
          pkgs.runCommand "kosmos-data-disk-backup-module-check" {} ''
            touch $out
          '';

      dagger-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/wsl/dagger.nix
            (_: {
              system.stateVersion = "25.05";
              kosmos.wsl.dagger.enable = true;
            })
          ];
        };
        cfg = eval.config;
        container = cfg.virtualisation.oci-containers.containers.dagger-engine;
        has = value: list: builtins.elem value list;
      in
        assert cfg.virtualisation.oci-containers.backend == "podman";
        assert container.autoStart;
        assert container.privileged;
        assert container.image == "registry.dagger.io/engine:v${cfg.kosmos.wsl.dagger.package.version}";
        assert container.pull == "missing";
        assert has "127.0.0.1:8080:8080" container.ports;
        assert has "/var/lib/dagger:/var/lib/dagger" container.volumes;
        assert has "/etc/dagger/engine.json:/etc/dagger/engine.json:ro" container.volumes;
        assert has "/run/dagger:/run/dagger" container.volumes;
        assert has "tcp://0.0.0.0:8080" container.cmd;
        assert has "unix:///run/dagger/engine.sock" container.cmd;
        assert has "L+ '/var/lib/dagger/config/dagger/engine.json' - - - - /etc/dagger/engine.json" cfg.systemd.tmpfiles.rules;
          pkgs.runCommand "kosmos-dagger-module-check" {} ''
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
