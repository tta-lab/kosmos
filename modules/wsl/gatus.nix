{
  config,
  lib,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.gatus;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposTunnel
    && config.kosmos.wsl.keposTunnel.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
  conditions = [
    "[STATUS] >= 200"
    "[STATUS] < 400"
    "[RESPONSE_TIME] < 10000"
  ];
in {
  options.kosmos.wsl.gatus = {
    enable = lib.mkEnableOption "Gatus status page";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Loopback port for the Gatus web interface.";
    };

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "status.guion.io";
      description = "Public hostname exposed through the Kepos Cloudflare tunnel.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveKeposTunnel) [
        ''
          Gatus is enabled without the Kepos Cloudflare tunnel.
          It will listen locally only at 127.0.0.1:${toString cfg.port}.
        ''
      ];

      services.gatus = {
        enable = true;
        package = pkgsUnstable.gatus;
        settings = {
          web = {
            address = "127.0.0.1";
            inherit (cfg) port;
          };
          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/data.db";
          };
          endpoints = [
            {
              name = "盛伟-网盘";
              url = "https://sw-file.guion.io";
              interval = "60s";
              inherit conditions;
            }
            {
              name = "盛伟-office";
              url = "https://sw-office.guion.io";
              interval = "60s";
              inherit conditions;
            }
          ];
        };
      };
    }

    (lib.mkIf haveKeposTunnel {
      services.cloudflared.tunnels.kepos.ingress.${cfg.publicHostname} = "http://127.0.0.1:${toString cfg.port}";
    })
  ]);
}
