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
      url = "github:tta-lab/kepos-neo/62081b4430916f2ee628932fe95a8ebff66775da";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = {
    self,
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
            tanka
            yq
          ];
        } ''
          shellcheck \
            ${./scripts/devops-gate-status} \
            ${./scripts/backup-ente} \
            ${./scripts/photos-gate-status} \
            ${./scripts/forgejo-https-git-smoke} \
            ${./scripts/forgejo-k8s-pull-secret-smoke} \
            ${./scripts/init-ebook-secrets} \
            ${./scripts/ttal-tmux-project-picker} \
            ${./scripts/wsl-devops-smoke} \
            ${./tests/temenos-env-test} \
            ${./tests/ttal-tmux-project-picker-test} \
            ${./tests/temenos-ca-test} \
            ${./tests/tmux-tmpdir-test} \
            ${./tests/tmux-copy-mode-test} \
            ${./tests/devops-gate-status-test} \
            ${./tests/backup-ente-test} \
            ${./tests/photos-gate-status-test} \
            ${./tests/sync-woodpecker-secret-test} \
            ${./tests/sync-ente-secret-test} \
            ${./tests/init-ebook-secrets-test} \
            ${./tests/ebooks-render-test} \
            ${./tests/ebook-gateway-render-test} \
            ${./tests/wsl-devops-smoke-test} \
            ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-tmux-project-picker-test}
          KOSMOS_REPO_ROOT=${./.} ${pkgs.python3}/bin/python3 ${./tests/test_sync_projects_auth.py}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-ca-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-tmpdir-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-copy-mode-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/devops-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/backup-ente-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/photos-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-woodpecker-secret-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-ente-secret-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/init-ebook-secrets-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ebooks-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ebook-gateway-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/wsl-devops-smoke-test}
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

      woodpecker-secret-sync-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {inherit agenix;};
          modules = [
            agenix.nixosModules.default
            ./modules/wsl/secrets.nix
            (_: {system.stateVersion = "25.05";})
          ];
        };
        cfg = eval.config;
        secret = cfg.age.secrets.woodpecker-server-env;
        unit = cfg.systemd.services.woodpecker-secret-sync;
        has = value: list: builtins.elem value list;
      in
        assert unit.restartTriggers == [secret.file];
        assert has "k3s.service" unit.after;
        assert has "k3s.service" unit.wants;
        assert has "multi-user.target" unit.wantedBy;
        assert unit.serviceConfig.Type == "oneshot";
        assert unit.serviceConfig.RemainAfterExit;
          pkgs.runCommand "woodpecker-secret-sync-module-check" {} "touch $out";

      ente-secret-sync-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {inherit agenix;};
          modules = [
            agenix.nixosModules.default
            ./modules/wsl/secrets.nix
            (_: {system.stateVersion = "25.05";})
          ];
        };
        cfg = eval.config;
        secret = cfg.age.secrets.ente-stack-env;
        unit = cfg.systemd.services.ente-secret-sync;
        has = value: list: builtins.elem value list;
      in
        assert secret.path == "/run/agenix/ente-stack-env";
        assert secret.mode == "0400";
        assert unit.restartTriggers == [secret.file];
        assert has "k3s.service" unit.after;
        assert has "k3s.service" unit.wants;
        assert has "multi-user.target" unit.wantedBy;
        assert unit.serviceConfig.Type == "oneshot";
        assert unit.serviceConfig.RemainAfterExit;
          pkgs.runCommand "ente-secret-sync-module-check" {} "touch $out";

      k3s-state-directories = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/wsl/proxy.nix
            ./modules/wsl/k3s.nix
            (_: {system.stateVersion = "25.05";})
          ];
        };
        inherit (eval.config.systemd.tmpfiles) rules;
      in
        assert builtins.elem "d /var/lib/kosmos-k3s/dagger 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ente 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ente/postgres 0700 999 999 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ente/garage 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/booklore/data 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/booklore/books 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/booklore/bookdrop 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/booklore-db 0700 999 999 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit/data 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit/books 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit-db 0700 999 999 - -" rules;
          pkgs.runCommand "k3s-state-directories-check" {} "touch $out";

      wsl-devops-cli = let
        cfg = self.nixosConfigurations.wsl.config;
        packageNames = map nixpkgs.lib.getName cfg.environment.systemPackages;
      in
        assert builtins.elem "dagger" packageNames;
        assert builtins.elem "kosmos-photos-gate-status" packageNames;
        assert cfg.environment.variables._EXPERIMENTAL_DAGGER_RUNNER_HOST == "tcp://127.0.0.1:8080";
          pkgs.runCommand "wsl-devops-cli-check" {} "touch $out";

      kepos-publisher-services = let
        cfg = self.nixosConfigurations.wsl.config;
        inherit (cfg.home-manager.users.neil.services.kepos.publisher) services;
        loopbackHosts = cfg.networking.hosts."127.0.0.1";
      in
        assert services.dagger.name == "Dagger";
        assert services.dagger.targetPort == 8080;
        assert services.dagger.allow == ["c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2"];
        assert services.booklore.name == "BookLore";
        assert services.booklore.targetPort == 17480;
        assert services.bookorbit.name == "BookOrbit";
        assert services.bookorbit.targetPort == 17480;
        assert builtins.elem "booklore.localhost" loopbackHosts;
        assert builtins.elem "bookorbit.localhost" loopbackHosts;
          pkgs.runCommand "kepos-publisher-services-check" {} "touch $out";

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
