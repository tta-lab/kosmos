{
  config,
  pkgs,
  ...
}: let
  token = config.age.secrets.cloudflare-ddns-token;
  selectAddress = pkgs.writeShellApplication {
    name = "kosmos-ddns-ipv6";
    runtimeInputs = [pkgs.iproute2 pkgs.python3];
    text = ''
      ip -j -6 address show dev eth1 | python3 ${../../scripts/select-ddns-ipv6}
    '';
  };
  syncSecret = pkgs.writeShellApplication {
    name = "kosmos-sync-caddy-secret";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ../../scripts/sync-caddy-secret;
  };
in {
  systemd = {
    services = {
      ddns-go = {
        description = "Update Cloudflare AAAA from the WSL service IPv6";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"];
        restartTriggers = [token.file];
        path = [pkgs.bash];
        preStart = ''
          ${pkgs.python3}/bin/python3 ${../../scripts/prepare-ddns-config} \
            "$CREDENTIALS_DIRECTORY/token" ${selectAddress}/bin/kosmos-ddns-ipv6 \
            "$RUNTIME_DIRECTORY/config.json"
        '';
        serviceConfig = {
          DynamicUser = true;
          LoadCredential = ["token:${token.path}"];
          RuntimeDirectory = "ddns-go";
          RuntimeDirectoryMode = "0700";
          StateDirectory = "ddns-go";
          WorkingDirectory = "/var/lib/ddns-go";
          UMask = "0077";
          ExecStart = "${pkgs.ddns-go}/bin/ddns-go -noweb -f 300 -c /run/ddns-go/config.json";
          Restart = "on-failure";
          RestartSec = "15s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
        };
      };

      caddy-secret-sync = {
        description = "Synchronize Caddy DNS-01 credential to local k3s";
        wantedBy = ["multi-user.target"];
        wants = ["k3s.service"];
        after = ["k3s.service"];
        restartTriggers = [token.file];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "10s";
          ExecStart = "${syncSecret}/bin/kosmos-sync-caddy-secret ${token.path}";
        };
      };

      public-https = {
        description = "Forward IPv6 HTTPS to the canonical Caddy Pod";
        serviceConfig = {
          DynamicUser = true;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:18443";
        };
      };
    };
    sockets.public-https = {
      description = "Public IPv6 HTTPS listener";
      wantedBy = ["sockets.target"];
      listenStreams = ["[::]:27443"];
      socketConfig.BindIPv6Only = "ipv6-only";
    };
  };
}
