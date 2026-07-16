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
            ${./scripts/devops-gate-status} \
            ${./scripts/forgejo-https-git-smoke} \
            ${./scripts/forgejo-k8s-pull-secret-smoke} \
            ${./scripts/ttal-tmux-project-picker} \
            ${./scripts/ttal-wezterm-projects} \
            ${./scripts/woodpecker-dagger-job-smoke} \
            ${./scripts/woodpecker-preflight} \
            ${./scripts/wsl-devops-smoke} \
            ${./tests/temenos-env-test} \
            ${./tests/ttal-tmux-project-picker-test} \
            ${./tests/temenos-ca-test} \
            ${./tests/feishin-web-cache-config-test} \
            ${./tests/cloudflared-ssh-config-test} \
            ${./tests/cloudflared-ingress-smoke-test} \
            ${./tests/dagger-large-registry-smoke-test} \
            ${./tests/dagger-engine-config-smoke-test} \
            ${./tests/dagger-engine-isolation-smoke-test} \
            ${./tests/tmux-tmpdir-test} \
            ${./tests/tmux-copy-mode-test} \
            ${./tests/devops-gate-status-test} \
            ${./tests/orga-cli-service-test} \
            ${./tests/ttal-wezterm-projects-test}
          WOODPECKER_DISABLE_UPDATE_CHECK=true woodpecker-cli lint --strict ${./fixtures/woodpecker/dagger-unix-socket-smoke.yml}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-tmux-project-picker-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-ca-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/feishin-web-cache-config-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/cloudflared-ssh-config-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/cloudflared-ingress-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/dagger-large-registry-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/dagger-engine-config-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/dagger-engine-isolation-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-tmpdir-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-copy-mode-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/devops-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-wezterm-projects-test}
          touch $out
        '';

      seafarer-edge-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/wsl/seafarer-edge.nix
            ({
              lib,
              pkgs,
              ...
            }: {
              options.kosmos.wsl.keposMatrix.enable = lib.mkEnableOption "test Kepos tunnel";
              config = {
                system.stateVersion = "25.05";
                kosmos.wsl = {
                  keposMatrix.enable = true;
                  seafarerEdge.enable = true;
                };
                services.cloudflared.tunnels.kepos = {
                  credentialsFile = pkgs.writeText "credentials.json" "{}";
                  default = "http_status:404";
                };
              };
            })
          ];
        };
        cfg = eval.config;
        edge = cfg.kosmos.wsl.seafarerEdge;
        caddyHost = cfg.services.caddy.virtualHosts."http://:${toString edge.proxyPort}";
      in
        assert cfg.services.caddy.enable;
        assert !cfg.services.nginx.enable;
        assert nixpkgs.lib.hasInfix "output discard" caddyHost.logFormat;
        assert nixpkgs.lib.hasInfix "bind 127.0.0.1" caddyHost.extraConfig;
        assert nixpkgs.lib.hasInfix "host ${edge.seafileHostname}" caddyHost.extraConfig;
        assert nixpkgs.lib.hasInfix "path /sdoc-server /sdoc-server/* /socket.io /socket.io/*" caddyHost.extraConfig;
        assert nixpkgs.lib.hasInfix "reverse_proxy 127.0.0.1:${toString edge.seadocPort}" caddyHost.extraConfig;
        assert nixpkgs.lib.hasInfix "header_up X-Forwarded-Proto https" caddyHost.extraConfig;
        assert nixpkgs.lib.hasInfix "reverse_proxy 127.0.0.1:${toString edge.seafilePort}" caddyHost.extraConfig;
        assert nixpkgs.lib.hasInfix "respond \"\" 404" caddyHost.extraConfig;
        assert cfg.services.cloudflared.tunnels.kepos.ingress.${edge.seafileHostname} == "http://127.0.0.1:${toString edge.proxyPort}";
        assert cfg.services.cloudflared.tunnels.kepos.ingress.${edge.onlyofficeHostname} == "http://127.0.0.1:${toString edge.onlyofficePort}";
          pkgs.runCommand "seafarer-edge-module-check" {} "touch $out";

      gatus-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/wsl/gatus.nix
            ./modules/wsl/seafarer-edge.nix
            ({lib, pkgs, ...}: {
              options.kosmos.wsl.keposMatrix.enable = lib.mkEnableOption "test Kepos tunnel";
              config = {
                system.stateVersion = "25.05";
                kosmos.wsl = {
                  keposMatrix.enable = true;
                  gatus.enable = true;
                  seafarerEdge.enable = true;
                };
                services.cloudflared.tunnels.kepos = {
                  credentialsFile = pkgs.writeText "credentials.json" "{}";
                  default = "http_status:404";
                };
              };
            })
          ];
        };
        cfg = eval.config;
        inherit (cfg.kosmos.wsl) gatus;
        inherit (cfg.services.gatus.settings) endpoints;
        endpoint = name: nixpkgs.lib.findFirst (item: item.name == name) null endpoints;
        fileEndpoint = endpoint "盛伟-网盘";
        officeEndpoint = endpoint "盛伟-office";
        expectedConditions = [
          "[STATUS] >= 200"
          "[STATUS] < 400"
          "[RESPONSE_TIME] < 10000"
        ];
      in
        assert cfg.services.gatus.enable;
        assert gatus.port == 8082;
        assert gatus.port != cfg.kosmos.wsl.seafarerEdge.proxyPort;
        assert cfg.services.gatus.settings.web.address == "127.0.0.1";
        assert cfg.services.gatus.settings.web.port == gatus.port;
        assert fileEndpoint.url == "https://sw-file.guion.io";
        assert fileEndpoint.interval == "60s";
        assert fileEndpoint.conditions == expectedConditions;
        assert officeEndpoint.url == "https://sw-office.guion.io";
        assert officeEndpoint.interval == "60s";
        assert officeEndpoint.conditions == expectedConditions;
        assert cfg.services.cloudflared.tunnels.kepos.ingress.${gatus.publicHostname} == "http://127.0.0.1:${toString gatus.port}";
          pkgs.runCommand "gatus-module-check" {} "touch $out";

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
        agent2 = cfg.services.woodpecker-agents.agents.wsl-podman-2;
        agentUnit = cfg.systemd.services.woodpecker-agent-wsl-podman;
        agentUnit2 = cfg.systemd.services.woodpecker-agent-wsl-podman-2;
        server = cfg.services.woodpecker-server;
        has = value: list: builtins.elem value list;
      in
        assert server.enable;
        assert server.environment.WOODPECKER_ENVIRONMENT == "_EXPERIMENTAL_DAGGER_RUNNER_HOST:unix:///run/dagger/engine.sock";
        assert agent.enable;
        assert agent2.enable;
        assert agent.environment.DOCKER_HOST == "unix:///run/podman/podman.sock";
        assert agent2.environment.DOCKER_HOST == "unix:///run/podman/podman.sock";
        assert agent.environment.WOODPECKER_BACKEND_DOCKER_VOLUMES == "/run/dagger:/run/dagger";
        assert has "podman.socket" agentUnit.after;
        assert has "podman-dagger-engine.service" agentUnit.after;
        assert has "forgejo-internal-registry-proxy.service" agentUnit.after;
        assert has "forgejo-internal-registry-proxy.service" agentUnit.wants;
        assert has "podman.socket" agentUnit2.after;
        assert has "podman-dagger-engine.service" agentUnit2.after;
        assert has "forgejo-internal-registry-proxy.service" agentUnit2.after;
        assert has "forgejo-internal-registry-proxy.service" agentUnit2.wants;
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
        assert forgejo.settings.server.ROOT_URL == "https://git.guion.io/";
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
        daggerUnit = cfg.systemd.services.podman-dagger-engine;
        dnsProxyUnit = cfg.systemd.services.dagger-dnsproxy;
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
        assert has "--dns=10.88.0.1" container.extraOptions;
        assert container.environment.HTTPS_PROXY == "http://host.containers.internal:7890";
        assert container.environment.NO_PROXY == "localhost,127.0.0.1,::1,host.containers.internal,10.87.0.0/16,10.88.0.0/16";
        assert cfg.kosmos.wsl.dagger.dockerHubMirrors == ["mirror.gcr.io"];
        assert cfg.kosmos.wsl.dagger.dnsUpstreams == ["127.0.0.1:1053"];
        assert has "dagger-dnsproxy.service" daggerUnit.after;
        assert has "dagger-dnsproxy.service" daggerUnit.wants;
        assert has "multi-user.target" dnsProxyUnit.wantedBy;
        assert has "mihomo.service" dnsProxyUnit.after;
        assert has "mihomo.service" dnsProxyUnit.wants;
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
