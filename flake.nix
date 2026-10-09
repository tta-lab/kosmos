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
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
    moonbit-overlay.inputs.nixpkgs.follows = "nixpkgs-unstable";
    kepos-neo = {
      url = "git+https://192.168.6.186:8086/LamplitIsles/kepos.git?ref=main&rev=3a34e3bea2f3afe49f833a5bd1f29d3ff48bb387";
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
    moonbit-overlay,
    kepos-neo,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    pkgsUnstable = import nixpkgs-unstable {inherit system;};
    moonbitToolchain = moonbit-overlay.packages.${system}.default;
  in {
    checks.${system} = {
      matrix-mcp-remote = let
        # Evaluation-only fixtures: never decrypted or activated.
        fixture = mode:
          (self.nixosConfigurations.wsl.extendModules {
            modules = [
              ({lib, ...}: {
                kosmos.wsl.matrixMcpRemote.enable = lib.mkForce (mode != "disabled");
                age.secrets = if mode == "absent" then lib.mkForce (builtins.removeAttrs enabled.age.secrets ["matrix-serein.env"]) else {
                  "matrix-serein.env" = {
                    file = lib.mkForce (pkgs.writeText "matrix-env-test-fixture.age" "not an encrypted credential");
                    owner = "neil";
                    group = "users";
                    mode = "0400";
                  };
                };
              })
            ];
          }).config;
        enabled = fixture "enabled";
        disabled = fixture "disabled";
        absent = fixture "absent";
        unit = enabled.home-manager.users.neil.systemd.user.services.matrix-mcp-remote;
        secret = enabled.age.secrets."matrix-serein.env";
        inherit (enabled.services.cloudflared.tunnels.kepos) ingress;
        inactive = cfg:
          !(cfg.home-manager.users.neil.systemd.user.services ? matrix-mcp-remote)
          && !(cfg.services.cloudflared.tunnels.kepos.ingress ? ${cfg.kosmos.wsl.matrixMcpRemote.hostname});
      in
        assert ingress.${enabled.kosmos.wsl.matrixMcpRemote.hostname} == "http://127.0.0.1:8768";
        assert ingress."serein-keet.guion.io" == "http://127.0.0.1:8767";
        assert enabled.services.cloudflared.tunnels.kepos.default == "http_status:404";
        assert inactive disabled && inactive absent;
        assert absent.warnings != [];
        assert secret.owner == "neil" && secret.group == "users" && secret.mode == "0400";
        assert secret.path == "/run/agenix/matrix-serein.env";
        assert unit.Service.EnvironmentFile == [secret.path];
        assert unit.Unit.ConditionPathExists == ["/home/neil/code/projects/lamplitisles/matrix-for-agent/dist/cli.js"];
        assert unit.Service.WorkingDirectory == "/home/neil/code/projects/lamplitisles/matrix-for-agent";
        assert unit.Service.KillMode == "control-group";
        assert unit.Service.StandardInput == "null";
        assert unit.Service.UMask == "0077";
        assert unit.Service.Restart == "on-failure" && unit.Service.TimeoutStopSec == 15;
          pkgs.runCommand "matrix-mcp-remote-check" {
            nativeBuildInputs = [pkgs.python3 pkgs.bash];
          } ''
            python3 ${./tests/matrix-for-agent-test.py} ${./scripts/matrix-for-agent-run}
            touch $out
          '';
      matrix-mcp-cfl = let
        # Only fake encrypted artifacts; evaluation never decrypts or activates.
        fixture = mode:
          (self.nixosConfigurations.wsl.extendModules {
            modules = [
              ({lib, ...}: {
                kosmos.wsl.matrixMcpRemote.enable = lib.mkForce (mode != "disabled");
                kosmos.wsl.matrixMcpCfl.enable = lib.mkForce (mode != "disabled");
                age.secrets = lib.mkForce (
                  builtins.removeAttrs self.nixosConfigurations.wsl.config.age.secrets [
                    "matrix-serein.env" "matrix-shio.env"
                  ]
                  // lib.optionalAttrs (builtins.elem mode ["both" "serein" "disabled"]) {
                    "matrix-serein.env" = {
                      file = pkgs.writeText "serein-matrix-fixture.age" "fake encrypted fixture";
                      owner = "neil";
                      group = "users";
                      mode = "0400";
                    };
                  }
                  // lib.optionalAttrs (builtins.elem mode ["both" "shio" "disabled"]) {
                    "matrix-shio.env" = {
                      file = pkgs.writeText "shio-matrix-fixture.age" "fake encrypted fixture";
                      owner = "neil";
                      group = "users";
                      mode = "0400";
                    };
                  }
                );
              })
            ];
          }).config;
        both = fixture "both";
        serein = fixture "serein";
        shio = fixture "shio";
        neither = fixture "neither";
        disabled = fixture "disabled";
        services = cfg: cfg.home-manager.users.neil.systemd.user.services;
        prodEnv = cfg: (services cfg).codex-for-love-prod.Service.EnvironmentFile or [];
        secret = both.age.secrets."matrix-shio.env";
        unit = (services both).matrix-mcp-cfl;
        ingress = cfg: cfg.services.cloudflared.tunnels.kepos.ingress;
      in
        assert (services both) ? matrix-mcp-remote && (services both) ? matrix-mcp-cfl;
        assert (services serein) ? matrix-mcp-remote && !((services serein) ? matrix-mcp-cfl);
        assert !((services shio) ? matrix-mcp-remote) && (services shio) ? matrix-mcp-cfl;
        assert !((services neither) ? matrix-mcp-remote) && !((services neither) ? matrix-mcp-cfl);
        assert !((services disabled) ? matrix-mcp-remote) && !((services disabled) ? matrix-mcp-cfl);
        assert (services both).matrix-mcp-remote == (services serein).matrix-mcp-remote;
        assert (services both).matrix-mcp-cfl == (services shio).matrix-mcp-cfl;
        assert ingress both == ingress serein;
        assert !(ingress shio ? "matrix-mcp.guion.io");
        assert serein.warnings != [] && neither.warnings != [];
        assert secret.path == "/run/agenix/matrix-shio.env";
        assert secret.owner == "neil" && secret.group == "users" && secret.mode == "0400";
        assert unit.Service.EnvironmentFile == [secret.path];
        assert unit.Service.UMask == "0077" && unit.Service.TimeoutStopSec == 15;
        assert unit.Service.KillMode == "control-group" && unit.Service.Restart == "on-failure";
        assert prodEnv both == prodEnv serein ++ [secret.path];
        assert prodEnv shio == prodEnv both && prodEnv neither == prodEnv serein;
        assert !(builtins.elem both.age.secrets."matrix-serein.env".path (prodEnv both));
        assert (services both).codex-for-love-dev == (services neither).codex-for-love-dev;
        assert (services both).codex-for-love-staging == (services neither).codex-for-love-staging;
        assert (services both).keet-mcp == (services neither).keet-mcp;
          pkgs.runCommand "matrix-mcp-cfl-check" {
            nativeBuildInputs = [pkgs.python3 pkgs.bash];
          } ''
            python3 ${./tests/matrix-for-agent-cfl-test.py} ${./scripts/matrix-for-agent-cfl-run}
            touch $out
          '';
      wsl-k3s-forwarding = assert self.nixosConfigurations.wsl.config.boot.kernel.sysctl."net.ipv4.conf.all.forwarding" == 1;
        pkgs.runCommand "wsl-k3s-forwarding-check" {} "touch $out";
      shell-tests =
        pkgs.runCommand "kosmos-shell-tests" {
          nativeBuildInputs = with pkgs; [
            bash
            coreutils
            fish
            findutils
            gawk
            git
            gnused
            gnutar
            jq
            just
            jsonnet
            python3
            caddy
            pkgsUnstable.traefik
            shellcheck
            tanka
            yq
            pkgsUnstable.bun
          ];
        } ''
          shellcheck \
            ${./scripts/devops-gate-status} \
            ${./scripts/sw-kubectl} \
            ${./scripts/validate-woodpecker-env} \
            ${./scripts/backup-ente} \
            ${./scripts/photos-gate-status} \
            ${./scripts/forgejo-https-git-smoke} \
            ${./scripts/forgejo-k8s-pull-secret-smoke} \
            ${./scripts/init-ebook-secrets} \
            ${./scripts/init-miniflux-secrets} \
            ${./scripts/init-observability-secrets} \
            ${./scripts/init-penpot-secrets} \
            ${./scripts/build-impri-images} \
            ${./scripts/sync-cloudreve-secret} \
            ${./scripts/backup-forgejo} \
            ${./scripts/sync-agent-config} \
            ${./scripts/install-tta-lab-go} \
            ${./scripts/sync-anki-secret} \
            ${./scripts/prepare-mihomo-config} \
            ${./scripts/render-kepos-policy} \
            ${./scripts/ttal-tmux-project-picker} \
            ${./scripts/wsl-devops-smoke} \
            ${./tests/temenos-env-test} \
            ${./tests/fish-copy-test} \
            ${./tests/ttal-tmux-project-picker-test} \
            ${./tests/temenos-ca-test} \
            ${./tests/tmux-copy-mode-test} \
            ${./tests/devops-gate-status-test} \
            ${./tests/backup-ente-test} \
            ${./tests/photos-gate-status-test} \
            ${./tests/photos-storage-render-test} \
            ${./tests/sync-ente-secret-test} \
            ${./tests/init-ebook-secrets-test} \
            ${./tests/sync-cloudreve-secret-test} \
            ${./tests/backup-forgejo-test} \
            ${./tests/forgejo-backup-render-test} \
            ${./tests/sw-devops-render-test} \
            ${./tests/validate-woodpecker-env-test} \
            ${./tests/prepare-mihomo-config-test} \
            ${./tests/render-kepos-policy-test} \
            ${./tests/observability-render-test} \
            ${./tests/ingress-render-test} \
            ${./tests/init-observability-secrets-test} \
            ${./tests/init-penpot-secrets-test} \
            ${./tests/penpot-render-test} \
            ${./tests/observability-just-test} \
            ${./tests/ebooks-render-test} \
            ${./tests/cloudreve-render-test} \
            ${./tests/anki-render-test} \
            ${./tests/notes-render-test} \
            ${./tests/feeds-render-test} \
            ${./tests/navidrome-render-test} \
            ${./tests/sync-anki-secret-test} \
            ${./tests/sync-codex-auth-test} \
            ${./tests/sync-agent-config-test} \
            ${./tests/wsl-devops-smoke-test} \
            ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ttal-tmux-project-picker-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-ca-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/temenos-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/fish-copy-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/tmux-copy-mode-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/devops-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/backup-ente-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/photos-gate-status-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/photos-storage-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-ente-secret-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/init-ebook-secrets-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-cloudreve-secret-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/backup-forgejo-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/forgejo-backup-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sw-devops-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/validate-woodpecker-env-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/prepare-mihomo-config-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/render-kepos-policy-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/observability-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ingress-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/init-observability-secrets-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/init-penpot-secrets-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/penpot-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/observability-just-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/ebooks-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/cloudreve-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/anki-render-test}
          tk fmt --test ${./.}/tests/jsonnet
          tk lint ${./.}/tests/jsonnet
          tk eval ${./.}/tests/jsonnet/codex-bridge.test.jsonnet >/dev/null
          tk eval ${./.}/tests/jsonnet/gateway.test.jsonnet >/dev/null
          tk eval ${./.}/tests/jsonnet/impri.test.jsonnet >/dev/null
          tk show --dangerous-allow-redirect ${./.}/tanka/environments/codex-bridge >/dev/null
          tk show --dangerous-allow-redirect ${./.}/tanka/environments/devops >/dev/null
          tk show --dangerous-allow-redirect ${./.}/tanka/environments/impri >/dev/null
          tk show --dangerous-allow-redirect ${./.}/tanka/environments/navidrome >/dev/null
          tk show --dangerous-allow-redirect ${./.}/tanka/environments/photos >/dev/null
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/notes-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/feeds-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/navidrome-render-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-anki-secret-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-codex-auth-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/sync-agent-config-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/wsl-devops-smoke-test}
          KOSMOS_REPO_ROOT=${./.} bash ${./tests/orga-cli-service-test}
          KOSMOS_REPO_ROOT=${./.} KOSMOS_CADDYFILE=${self.nixosConfigurations.wsl.config.services.caddy.configFile} python3 ${./tests/http-gateway-test.py}
          touch $out
        '';

      kepos-tunnel-module = let
        eval = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {inherit pkgsUnstable;};
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            ./modules/wsl/kepos-tunnel.nix
            ./modules/wsl/matrix-mcp-remote.nix
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
        assert tunnel.ingress."serein-keet.guion.io" == "http://127.0.0.1:8767";
        assert tunnel.ingress."test.guion.io" == "http://127.0.0.1:8080";
        assert cfg.systemd.services.cloudflared-tunnel-kepos.environment.TUNNEL_TRANSPORT_PROTOCOL == "http2";
          pkgs.runCommand "kepos-tunnel-module-check" {} "touch $out";

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
        assert vpn.config
        == ''
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
        assert builtins.elem 9475 eval.config.networking.firewall.interfaces.cni0.allowedTCPPorts;
        assert !(builtins.elem 9475 eval.config.networking.firewall.allowedTCPPorts);
        assert builtins.elem "k3s-node-address.service" eval.config.systemd.services.k3s.requires;
        assert builtins.elem "d /var/lib/kosmos-k3s/dagger 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit/data 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit/books 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/ebooks/bookorbit-db 0700 999 999 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/anki 0750 1000 1000 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/notes/memos 0750 10001 10001 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/observability 0750 root root - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/observability/victoria-metrics 0750 65534 65534 - -" rules;
        assert builtins.elem "d /var/lib/kosmos-k3s/observability/grafana 0750 472 472 - -" rules;
          pkgs.runCommand "k3s-state-directories-check" {} "touch $out";

      wsl-devops-cli = let
        cfg = self.nixosConfigurations.wsl.config;
        packageNames = map nixpkgs.lib.getName cfg.environment.systemPackages;
      in
        assert builtins.elem "dagger" packageNames;
        assert builtins.elem "kosmos-photos-gate-status" packageNames;
        assert cfg.environment.variables._EXPERIMENTAL_DAGGER_RUNNER_HOST == "tcp://127.0.0.1:8080";
        assert cfg.home-manager.users.neil.home.sessionVariables.WOODPECKER_URL == "https://192.168.6.186:8087";
          pkgs.runCommand "wsl-devops-cli-check" {} "touch $out";

      wsl-seafarer-ca-trust = let
        cfg = self.nixosConfigurations.wsl.config;
        homeSessionVariables = cfg.home-manager.users.neil.home.sessionVariables;
      in
        assert homeSessionVariables.NODE_EXTRA_CA_CERTS == cfg.security.pki.caBundle;
          pkgs.runCommand "wsl-seafarer-ca-trust-check" {
            nativeBuildInputs = [pkgs.openssl];
          } ''
            openssl verify \
              -no_check_time \
              -CAfile ${cfg.security.pki.caBundle} \
              ${./certs/seafarer-root-ca.pem}
            touch "$out"
          '';

      wsl-mihomo-service = let
        cfg = self.nixosConfigurations.wsl.config;
        expectedConfig = "/mnt/c/Users/white/AppData/Roaming/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml";
        expectedLocalEndpoint = "127.0.0.1:7890";
        expectedPodEndpoint = "10.42.0.1:7890";
        expectedPodCidr = "10.42.0.0/16";
        expectedServiceCidr = "10.43.0.0/16";
        expectedProxy = "http://${expectedLocalEndpoint}";
        expectedNoProxyEntries = [
          "localhost"
          "127.0.0.1"
          "::1"
          "192.168.6.186"
        ];
        expectedNoProxy = nixpkgs.lib.concatStringsSep "," expectedNoProxyEntries;
        expectedProxyEnvironment = {
          HTTP_PROXY = expectedProxy;
          HTTPS_PROXY = expectedProxy;
          ALL_PROXY = expectedProxy;
          NO_PROXY = expectedNoProxy;
          http_proxy = expectedProxy;
          https_proxy = expectedProxy;
          all_proxy = expectedProxy;
          no_proxy = expectedNoProxy;
        };
        expectedK3sNoProxy = nixpkgs.lib.concatStringsSep "," (
          expectedNoProxyEntries
          ++ [
            expectedPodCidr
            expectedServiceCidr
            ".svc"
            ".cluster.local"
            "10.255.255.1"
            "grafana.localhost"
            "impri.localhost"
          ]
        );
        has = value: list: builtins.elem value list;
        unit = cfg.systemd.services.mihomo;
        cniSocket = cfg.systemd.sockets.mihomo-cni-proxy;
        cniProxy = cfg.systemd.services.mihomo-cni-proxy;
        nixDaemonEnvironment = cfg.systemd.services.nix-daemon.environment;
        proxyEnvironment = cfg.kosmos.wsl.proxy.environment;
        k3sEnvironment = cfg.systemd.services.k3s.environment;
        homeSessionVariables = cfg.home-manager.users.neil.home.sessionVariables;
        temenosEnvironment = cfg.home-manager.users.neil.systemd.user.services.temenos.Service.Environment;
        proxyEnvironmentEntries = nixpkgs.lib.mapAttrsToList (name: value: "${name}=${value}") expectedProxyEnvironment;
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
        assert cfg.kosmos.wsl.proxy.url == expectedProxy;
        assert cfg.kosmos.wsl.proxy.localEndpoint == expectedLocalEndpoint;
        assert cfg.kosmos.wsl.proxy.podEndpoint == expectedPodEndpoint;
        assert cfg.kosmos.wsl.proxy.podCidr == expectedPodCidr;
        assert cfg.kosmos.wsl.proxy.serviceCidr == expectedServiceCidr;
        assert cfg.kosmos.wsl.proxy.noProxy == expectedNoProxyEntries;
        assert proxyEnvironment == expectedProxyEnvironment;
        assert cfg.environment.variables.HTTP_PROXY == expectedProxy;
        assert cfg.networking.proxy.default == expectedProxy;
        assert cfg.networking.proxy.noProxy == expectedNoProxy;
        assert nixDaemonEnvironment.http_proxy == expectedProxy;
        assert nixDaemonEnvironment.https_proxy == expectedProxy;
        assert nixDaemonEnvironment.no_proxy == expectedNoProxy;
        assert homeSessionVariables.PI_RETRY_STALL_TIMEOUT_MS == "0";
        assert homeSessionVariables.TACT_MODEL == "terra";
        assert builtins.all (name: homeSessionVariables.${name} == expectedProxyEnvironment.${name}) (builtins.attrNames expectedProxyEnvironment);
        assert k3sEnvironment.HTTP_PROXY == expectedProxy;
        assert k3sEnvironment.HTTPS_PROXY == expectedProxy;
        assert k3sEnvironment.ALL_PROXY == expectedProxy;
        assert k3sEnvironment.http_proxy == expectedProxy;
        assert k3sEnvironment.https_proxy == expectedProxy;
        assert k3sEnvironment.all_proxy == expectedProxy;
        assert k3sEnvironment.NO_PROXY == expectedK3sNoProxy;
        assert k3sEnvironment.no_proxy == expectedK3sNoProxy;
        assert builtins.all (entry: has entry temenosEnvironment) proxyEnvironmentEntries;
        assert has "mihomo.service" cfg.systemd.services.k3s.wants;
        assert has "mihomo.service" cfg.systemd.services.k3s.after;
        assert !cfg.systemd.services.firewall.enable;
        assert !has 7890 cfg.networking.firewall.interfaces.cni0.allowedTCPPorts;
        assert cniSocket.listenStreams == [expectedPodEndpoint];
        assert cniSocket.socketConfig.FreeBind;
        assert has "mihomo.service" cniProxy.requires;
        assert has "mihomo.service" cniProxy.after;
        assert nixpkgs.lib.hasSuffix "systemd-socket-proxyd ${expectedLocalEndpoint}" cniProxy.serviceConfig.ExecStart;
          pkgs.runCommand "wsl-mihomo-service-check" {} "touch $out";

      wsl-proxy-environment-file = let
        cfg = self.nixosConfigurations.wsl.config;
        proxyFile = cfg.environment.etc."kosmos/proxy.env".source;
      in
        pkgs.runCommand "wsl-proxy-environment-file-check" {} ''
          source ${nixpkgs.lib.escapeShellArg proxyFile}
          test "$HTTP_PROXY" = http://127.0.0.1:7890
          test "$http_proxy" = "$HTTP_PROXY"
          test "$NO_PROXY" = localhost,127.0.0.1,::1,192.168.6.186
          test "$no_proxy" = "$NO_PROXY"
          touch "$out"
        '';

      wsl-zsh-session-variables = let
        cfg = self.nixosConfigurations.wsl.config;
        inherit (self.nixosConfigurations.wsl.pkgs) zsh;
      in
        pkgs.runCommand "wsl-zsh-session-variables-check" {} ''
          unset __HM_SESS_VARS_SOURCED
          ${zsh}/bin/zsh -dfc '
            source "$1"
            test "$PI_RETRY_STALL_TIMEOUT_MS" = 0
            test "$HTTP_PROXY" = http://127.0.0.1:7890
          ' zsh ${nixpkgs.lib.escapeShellArg cfg.home-manager.users.neil.home.file.".zshrc".source}
          touch "$out"
        '';

      nix-cache-policy = let
        cfg = self.nixosConfigurations.wsl.config;
        has = value: list: builtins.elem value list;
        inherit (cfg.nix.settings) substituters;
        extraSubstituters = cfg.nix.settings.extra-substituters;
        trustedPublicKeys = cfg.nix.settings.trusted-public-keys;
        extraTrustedPublicKeys = cfg.nix.settings.extra-trusted-public-keys;
      in
        assert has "https://cache.nixos.org/" substituters;
        assert has "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=30" extraSubstituters;
        assert has "https://fenix.cachix.org" extraSubstituters;
        assert has "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" trustedPublicKeys;
        assert has "fenix.cachix.org-1:ecJhr+RdYEdcVgUkjruiYhjbBloIEGov7bos90cZi0Q=" extraTrustedPublicKeys;
        assert cfg.nix.settings.trusted-users == ["root"];
          pkgs.runCommand "nix-cache-policy-check" {} "touch $out";

      wsl-codex-for-love-services = let
        cfg = self.nixosConfigurations.wsl.config;
        inherit (cfg.home-manager.users.neil.systemd.user) services;
        homeSessionVariables = cfg.home-manager.users.neil.home.sessionVariables;
        expectedBasePath = "PATH=/home/neil/.local/bin:/home/neil/go/bin:/home/neil/.local/share/npm-global/bin:/run/current-system/sw/bin";
        expectedProdPath = "PATH=/home/neil/.local/bin:/home/neil/go/bin:/home/neil/.local/share/npm-global/bin:/run/current-system/sw/bin:/home/neil/.cache/.bun/bin";
        haveProdMeiliSecret = builtins.pathExists ./secrets/codex-for-love-prod.env.age;
        prodMeiliSecret = cfg.age.secrets."codex-for-love-prod.env";
      in
        assert builtins.elem expectedBasePath services.codex-for-love-dev.Service.Environment;
        assert builtins.elem expectedBasePath services.codex-for-love-staging.Service.Environment;
        assert builtins.elem expectedProdPath services.codex-for-love-prod.Service.Environment;
        assert homeSessionVariables.FLICKLOG_MEILI_URL == "http://meilisearch.localhost:17480/";
        assert !haveProdMeiliSecret || builtins.elem "FLICKLOG_MEILI_URL=http://meilisearch.localhost:17480/" services.codex-for-love-prod.Service.Environment;
        assert !haveProdMeiliSecret || services.codex-for-love-prod.Service.EnvironmentFile == [prodMeiliSecret.path] ++ nixpkgs.lib.optional (cfg.age.secrets ? "matrix-shio.env") cfg.age.secrets."matrix-shio.env".path;
        assert !haveProdMeiliSecret || prodMeiliSecret.path == "${cfg.age.secretsDir}/${prodMeiliSecret.name}";
          pkgs.runCommand "wsl-codex-for-love-services-check" {} "touch $out";

      kepos-live-policy = let
        cfg = self.nixosConfigurations.wsl.config;
        home = cfg.home-manager.users.neil;
        package = kepos-neo.packages.${system}.kepos;
        dashboardPackage = kepos-neo.packages.${system}.grafana-dashboard;
        peerUnit = home.systemd.user.services.kepos-peer;
        peerPolicyFile = "/home/neil/.config/kepos/peer.toml";
        peerStateDir = "/home/neil/.local/state/kepos-neo/peer";
      in
        # Policy is intentionally external to the Nix closure and is migrated
        # manually before this generation is activated.
        assert !(builtins.hasAttr "kepos" home.services);
        assert !(builtins.hasAttr "kepos/peer.toml" home.xdg.configFile);
        assert home.systemd.user.startServices;
        assert peerUnit.Install.WantedBy == ["default.target"];
        assert peerUnit.Service.UMask == "0077";
        assert !(peerUnit.Service ? ExecStartPre);
        assert !(peerUnit.Service ? Environment);
        assert nixpkgs.lib.hasInfix "--state ${peerStateDir}" peerUnit.Service.ExecStart;
        assert nixpkgs.lib.hasInfix "--config ${peerPolicyFile}" peerUnit.Service.ExecStart;
        assert nixpkgs.lib.hasInfix "--metrics-listen 10.255.255.1:9475" peerUnit.Service.ExecStart;
        assert builtins.elem dashboardPackage cfg.environment.systemPackages;
        assert builtins.elem "/share/kepos" cfg.environment.pathsToLink;
          pkgs.runCommand "kepos-live-policy-check" {
            nativeBuildInputs = [
              package
              pkgs.jsonnet
            ];
          } ''
            set -euo pipefail

            state_dir="$TMPDIR/peer"
            config_file="$TMPDIR/peer.toml"
            jsonnet -S ${./kepos/peer-policy.jsonnet} >"$config_file"
            kepos setup peer --state "$state_dir" --config "$config_file" >/dev/null
            key_output="$(kepos peer key --state "$state_dir")"
            [[ "$key_output" =~ ^Peer\ key:\ [0-9a-f]{64}$ ]]
            kepos peer status --state "$state_dir" --config "$config_file"
            test -f ${dashboardPackage}/share/kepos/grafana/kepos-publisher-observability.json
            touch "$out"
          '';
    };

    nixosConfigurations.kosmos = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit moonbitToolchain pkgsUnstable;
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
        inherit agenix fenix kepos-neo moonbitToolchain nixpkgs-unstable pkgsUnstable;
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
