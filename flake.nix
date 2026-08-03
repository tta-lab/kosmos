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
            ${./scripts/sync-anki-secret} \
            ${./scripts/prepare-mihomo-config} \
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
            ${./tests/prepare-mihomo-config-test} \
            ${./tests/ebooks-render-test} \
            ${./tests/ebook-gateway-render-test} \
            ${./tests/anki-render-test} \
            ${./tests/anki-gateway-render-test} \
            ${./tests/notes-render-test} \
            ${./tests/notes-gateway-render-test} \
            ${./tests/sync-anki-secret-test} \
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
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/prepare-mihomo-config-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ebooks-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ebook-gateway-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/anki-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/anki-gateway-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/notes-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/notes-gateway-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-anki-secret-test}
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

      anki-secret-sync-module = let
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
        secret = cfg.age.secrets.anki-sync-env;
        unit = cfg.systemd.services.anki-secret-sync;
        has = value: list: builtins.elem value list;
      in
        assert secret.path == "/run/agenix/anki-sync-env";
        assert secret.mode == "0400";
        assert unit.restartTriggers == [secret.file];
        assert has "k3s.service" unit.after;
        assert has "k3s.service" unit.wants;
        assert has "multi-user.target" unit.wantedBy;
        assert unit.serviceConfig.Type == "oneshot";
        assert unit.serviceConfig.RemainAfterExit;
          pkgs.runCommand "anki-secret-sync-module-check" {} "touch $out";

      openvpn-client-module = let
        cfg = self.nixosConfigurations.wsl.config;
        vpn = cfg.services.openvpn.servers.client;
        configSecret = cfg.age.secrets.openvpn-config;
        authSecret = cfg.age.secrets.openvpn-auth;
        unit = cfg.systemd.services.openvpn-client;
      in
        assert configSecret.path == "/run/agenix/openvpn-config";
        assert configSecret.mode == "0400";
        assert authSecret.path == "/run/agenix/openvpn-auth";
        assert authSecret.mode == "0400";
        assert vpn.autoStart;
        assert vpn.config == ''
          config ${configSecret.path}
          auth-user-pass ${authSecret.path}
          data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC
        '';
        assert builtins.elem "multi-user.target" unit.wantedBy;
        assert unit.serviceConfig.Restart == "always";
          pkgs.runCommand "openvpn-client-module-check" {} "touch $out";

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
        k3sFlags = eval.config.services.k3s.extraFlags;
      in
        assert builtins.elem "--node-ip=10.255.255.1" k3sFlags;
        assert builtins.elem "k3s-node-address.service" eval.config.systemd.services.k3s.requires;
        assert builtins.elem "d /var/lib/kosmos-k3s/dagger 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ente 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ente/postgres 0700 999 999 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ente/garage 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit/data 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit/books 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit-db 0700 999 999 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/anki 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/notes/memos 0750 10001 10001 - -" rules;
          pkgs.runCommand "k3s-state-directories-check" {} "touch $out";

      wsl-devops-cli = let
        cfg = self.nixosConfigurations.wsl.config;
        packageNames = map nixpkgs.lib.getName cfg.environment.systemPackages;
      in
        assert builtins.elem "dagger" packageNames;
        assert builtins.elem "kosmos-photos-gate-status" packageNames;
        assert cfg.environment.variables._EXPERIMENTAL_DAGGER_RUNNER_HOST == "tcp://127.0.0.1:8080";
          pkgs.runCommand "wsl-devops-cli-check" {} "touch $out";

      wsl-mihomo-service = let
        cfg = self.nixosConfigurations.wsl.config;
        expectedConfig = "/mnt/c/Users/white/AppData/Roaming/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml";
        expectedProxy = "http://127.0.0.1:7890";
        expectedProxyEnvironment = [
          "HTTP_PROXY=${expectedProxy}"
          "HTTPS_PROXY=${expectedProxy}"
          "ALL_PROXY=${expectedProxy}"
          "NO_PROXY=localhost,127.0.0.1,::1"
          "http_proxy=${expectedProxy}"
          "https_proxy=${expectedProxy}"
          "all_proxy=${expectedProxy}"
          "no_proxy=localhost,127.0.0.1,::1"
        ];
        has = value: list: builtins.elem value list;
        unit = cfg.systemd.services.mihomo;
        cniSocket = cfg.systemd.sockets.mihomo-cni-proxy;
        cniProxy = cfg.systemd.services.mihomo-cni-proxy;
        flicknoteEnvironment = cfg.home-manager.users.neil.systemd.user.services.flicknote-sync.Service.Environment;
      in
        assert cfg.services.mihomo.enable;
        assert cfg.services.mihomo.configFile == expectedConfig;
        assert !cfg.services.mihomo.tunMode;
        assert cfg.services.mihomo.webui != null;
        assert cfg.services.mihomo.webui == self.nixosConfigurations.wsl.pkgs.metacubexd;
        assert unit.serviceConfig.LoadCredential == "config.yaml:${expectedConfig}";
        assert unit.serviceConfig ? RuntimeDirectory;
        assert unit.serviceConfig.RuntimeDirectory == "mihomo-runtime";
        assert unit.serviceConfig.RuntimeDirectoryMode == "0700";
        assert unit.serviceConfig ? ExecStartPre;
        assert nixpkgs.lib.hasInfix "\${RUNTIME_DIRECTORY}/config.yaml" unit.serviceConfig.ExecStart;
        assert nixpkgs.lib.hasInfix "-ext-ui " unit.serviceConfig.ExecStart;
        assert cfg.kosmos.wsl.k3sProxyUrl == expectedProxy;
        assert cfg.environment.variables.HTTP_PROXY == expectedProxy;
        assert has "mihomo.service" cfg.systemd.services.k3s.wants;
        assert has "mihomo.service" cfg.systemd.services.k3s.after;
        assert !cfg.systemd.services.firewall.enable;
        assert !has 7890 cfg.networking.firewall.interfaces.cni0.allowedTCPPorts;
        assert cniSocket.listenStreams == ["10.42.0.1:7890"];
        assert cniSocket.socketConfig.FreeBind;
        assert has "mihomo.service" cniProxy.requires;
        assert has "mihomo.service" cniProxy.after;
        assert nixpkgs.lib.hasSuffix "systemd-socket-proxyd 127.0.0.1:7890" cniProxy.serviceConfig.ExecStart;
        assert builtins.all (value: has value flicknoteEnvironment) expectedProxyEnvironment;
          pkgs.runCommand "wsl-mihomo-service-check" {} "touch $out";

      kepos-publisher-services = let
        cfg = self.nixosConfigurations.wsl.config;
        inherit (cfg.home-manager.users.neil.services.kepos.publisher) allow services;
        loopbackHosts = cfg.networking.hosts."127.0.0.1";
        transportAllow = [
          "c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2"
          "d1c8e7bad4f0468a12d54c5b80d175677ff58c833f9e666f8a838b0d6b9256bc"
          "ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e"
          "682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90"
          "f8bcb7c20d24d3a295fdec2a5a250adef59b3d7e70b21592a01de99b63cae6de"
          "de087b86a5ced0d4f85e63463b8508e42ede89d2d4c9c9a64efd52697b1ce78b"
        ];
        forgeAllow = [
          "c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2"
          "ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e"
          "682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90"
          "de087b86a5ced0d4f85e63463b8508e42ede89d2d4c9c9a64efd52697b1ce78b"
        ];
      in
        assert allow == transportAllow;
        assert builtins.all (service: services.${service}.allow == null) [
          "navidrome"
          "ente"
          "ente-storage"
          "bookorbit"
          "anki"
          "memos"
          "mihomo"
          "ssh"
        ];
        assert services.forgejo.allow == forgeAllow;
        assert services.woodpecker.allow == forgeAllow;
        assert services.dagger.name == "Dagger";
        assert services.dagger.targetPort == 8080;
        assert services.dagger.allow == ["c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2"];
        assert services.bookorbit.name == "BookOrbit";
        assert services.bookorbit.targetPort == 17480;
        assert services.anki.name == "Anki";
        assert services.anki.targetPort == 17480;
        assert services.memos.name == "Memos";
        assert services.memos.targetPort == 17480;
        assert services ? mihomo;
        assert services.mihomo.name == "Mihomo";
        assert services.mihomo.targetPort == 7890;
        assert builtins.hasAttr "mihomo-dashboard" services;
        assert services."mihomo-dashboard".name == "Mihomo Dashboard";
        assert services."mihomo-dashboard".targetPort == 9090;
        assert services."mihomo-dashboard".allow == ["c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2"];
        assert builtins.elem "bookorbit.localhost" loopbackHosts;
        assert builtins.elem "anki.localhost" loopbackHosts;
        assert builtins.elem "memos.localhost" loopbackHosts;
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
