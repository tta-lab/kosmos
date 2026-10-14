{config, lib, pkgs, ...}: let
  routes = builtins.fromJSON (builtins.readFile ../../http/cluster-routes.json);
  clusterVpnHosts = lib.mapAttrsToList (id: _: "${id}.nuc.swdl") routes;
  clusterHosts = lib.concatMap (route: route.hosts) (builtins.attrValues routes);
  localRoutes = {
    dev-her = 3082;
    staging-her = 3083;
    prod-lamplit = 3084;
    flickgrove = 4318;
    mihomo-dashboard = 9090;
  };
  haveTls = config.age.secrets ? nuc-vpn-cert && config.age.secrets ? nuc-vpn-key;
  cert = if haveTls then config.age.secrets.nuc-vpn-cert.path else "/run/agenix/nuc-vpn-cert";
  key = if haveTls then config.age.secrets.nuc-vpn-key.path else "/run/agenix/nuc-vpn-key";
  vpnConfig = pkgs.writeText "nuc-vpn-caddyfile" ''
    https://:443 {
      bind 10.80.12.4
      tls ${cert} ${key}
      route {
        @storage {
          host ente-storage.nuc.swdl
          remote_ip 10.42.0.0/16
        }
        handle @storage {
          reverse_proxy 127.0.0.1:27480 {
            transport http {
              read_buffer 512k
            }
          }
        }
        @outside not remote_ip 10.80.12.0/24
        handle @outside {
          respond "VPN source required" 403
        }
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: port: ''
          @${id} host ${id}.nuc.swdl
          handle @${id} {
            reverse_proxy 127.0.0.1:${toString port}
          }
        '') localRoutes)}
        @cluster host ${lib.concatStringsSep " " clusterVpnHosts}
        handle @cluster {
          reverse_proxy 127.0.0.1:27480 {
            transport http {
              read_buffer 512k
            }
          }
        }
        handle {
          respond "unknown host" 421
        }
      }
    }
  '';
  prepare = pkgs.writeShellApplication {
    name = "prepare-vpn-https";
    runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.iproute2 pkgs.openssl config.services.caddy.package];
    text = builtins.readFile ../../scripts/prepare-vpn-https;
  };
  prepareCommand =
    if haveTls
    then "${prepare}/bin/prepare-vpn-https ${cert} ${key} ${../../certs/seafarer-root-ca.pem} ${vpnConfig} /run/caddy/vpn/https.caddy"
    else "${pkgs.coreutils}/bin/rm -f /run/caddy/vpn/https.caddy";
in {
  networking.hosts."127.0.0.1" = lib.mapAttrsToList (id: _: "${id}.localhost") localRoutes;

  services.caddy = {
    enable = true;
    globalConfig = ''
      auto_https off
      admin unix//run/caddy/admin.sock
      servers {
        protocols h1 h2
        max_header_size 1MB
      }
    '';
    extraConfig = ''
      import /run/caddy/vpn/*.caddy
      http://:17480 {
        bind 127.0.0.1
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: port: ''
          @${id} host ${id}.localhost
          handle @${id} {
            reverse_proxy 127.0.0.1:${toString port}
          }
        '')
        localRoutes)}
        @cluster host ${lib.concatStringsSep " " clusterHosts}
        handle @cluster {
          reverse_proxy 127.0.0.1:27480 {
            transport http {
              read_buffer 512k
            }
          }
        }
        handle {
          respond "unknown host" 421
        }
      }
    '';
  };
  # Public configuration only: certificate/key material stays in agenix.
  environment.etc."caddy/vpn-template".source = vpnConfig;
  systemd.services.caddy.serviceConfig = {
    RuntimeDirectory = "caddy";
    ExecStartPre = lib.mkBefore [prepareCommand];
    # The pinned NixOS module resets ExecReload; preparation must follow that reset.
    ExecReload = lib.mkForce [
      ""
      prepareCommand
      "${lib.getExe config.services.caddy.package} reload --config /etc/caddy/caddy_config --adapter caddyfile --force"
    ];
  };
}
