{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.seafarerEdge;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposMatrix
    && config.kosmos.wsl.keposMatrix.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;
in {
  options.kosmos.wsl.seafarerEdge = {
    enable = lib.mkEnableOption "Seafarer ingress through the WSL Cloudflare tunnel";

    enableCloudflared = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Seafarer through the existing WSL Cloudflare tunnel.";
    };

    seafileHostname = lib.mkOption {
      type = lib.types.str;
      default = "seafile.guion.io";
      description = "Public Seafile hostname exposed through cloudflared.";
    };

    onlyofficeHostname = lib.mkOption {
      type = lib.types.str;
      default = "onlyoffice.guion.io";
      description = "Public OnlyOffice hostname exposed through cloudflared.";
    };

    seafilePort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "Loopback port published by the Seafile container.";
    };

    seadocPort = lib.mkOption {
      type = lib.types.port;
      default = 18081;
      description = "Loopback port published by the SeaDoc container.";
    };

    onlyofficePort = lib.mkOption {
      type = lib.types.port;
      default = 18082;
      description = "Loopback port published by the OnlyOffice container.";
    };

    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Loopback port used by the Seafile path-routing proxy.";
    };

    classifierPort = lib.mkOption {
      type = lib.types.port;
      default = 18083;
      description = "Loopback port published by the PDF classifier.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (cfg.enableCloudflared && !haveKeposTunnel) [
        ''
          Seafarer edge routing is enabled without the kepos Cloudflare tunnel.
          The local proxy will remain available on 127.0.0.1:${toString cfg.proxyPort}.
        ''
      ];

      services.caddy = {
        enable = true;
        virtualHosts."http://:${toString cfg.proxyPort}" = {
          logFormat = "output discard";
          extraConfig = ''
            bind 127.0.0.1

            @seadoc {
              host ${cfg.seafileHostname}
              path /sdoc-server /sdoc-server/* /socket.io /socket.io/*
            }
            handle @seadoc {
              reverse_proxy 127.0.0.1:${toString cfg.seadocPort} {
                header_up X-Forwarded-Proto https
              }
            }

            @classifier {
              host ${cfg.seafileHostname}
              path /upload /upload/*
            }
            handle @classifier {
              reverse_proxy 127.0.0.1:${toString cfg.classifierPort} {
                header_up X-Forwarded-Proto https
              }
            }

            @seafile host ${cfg.seafileHostname}
            handle @seafile {
              reverse_proxy 127.0.0.1:${toString cfg.seafilePort} {
                header_up X-Forwarded-Proto https
              }
            }

            handle {
              respond "" 404
            }
          '';
        };
      };
    }

    (lib.mkIf (cfg.enableCloudflared && haveKeposTunnel) {
      services.cloudflared.tunnels.kepos.ingress = {
        ${cfg.seafileHostname} = "http://127.0.0.1:${toString cfg.proxyPort}";
        ${cfg.onlyofficeHostname} = "http://127.0.0.1:${toString cfg.onlyofficePort}";
      };
    })
  ]);
}
