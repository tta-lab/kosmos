{lib, ...}: let
  routes = builtins.fromJSON (builtins.readFile ../../http/cluster-routes.json);
  clusterHosts = lib.concatMap (route: route.hosts) (builtins.attrValues routes);
  localRoutes = {
    dev-her = 3082;
    staging-her = 3083;
    prod-lamplit = 3084;
    flickgrove = 4318;
    mihomo-dashboard = 9090;
  };
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
  systemd.services.caddy.serviceConfig.RuntimeDirectory = "caddy";
}
