{config, lib, pkgs, ...}: let
  routes = builtins.fromJSON (builtins.readFile ../../http/cluster-routes.json);
  clusterVpnHosts = lib.mapAttrsToList (id: _: "${id}.nuc.guion.io") routes;
  clusterHosts = lib.concatMap (route: route.hosts) (builtins.attrValues routes);
  localRoutes = {
    dev-her = 3082;
    staging-her = 3083;
    prod-lamplit = 3084;
    flickgrove = 4318;
    mihomo-dashboard = 9090;
  };
  haveToken = config.age.secrets ? cloudflare-ddns-token;
  token = if haveToken then config.age.secrets.cloudflare-ddns-token.path else "/run/agenix/cloudflare-ddns-token";
  caddy = (pkgs.caddy.withPlugins {
    plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
    hash = "sha256-pRrLBlYRaAyMYwPXeTy4WqWNRu/L9K6Mn2src11dGh8=";
  }).overrideAttrs (old: {
    # The upstream invalid-format error includes the token; never log that value.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace vendor/github.com/caddy-dns/cloudflare/cloudflare.go \
        --replace-fail "return fmt.Errorf(\"API token '%s' appears invalid; ensure it's correctly entered and not wrapped in braces nor quotes\", p.Provider.APIToken)" \
        'return fmt.Errorf("Cloudflare API token format is invalid")'
    '';
  });
  vpnConfig = pkgs.writeText "nuc-vpn-caddyfile" ''
    https://*.nuc.guion.io:443 {
      bind 10.80.12.4
      tls {
        issuer acme {
          dir https://acme-v02.api.letsencrypt.org/directory
          timeout 2m
          disable_http_challenge
          disable_tlsalpn_challenge
          dns cloudflare {file.${token}}
          resolvers 1.1.1.1:53 8.8.8.8:53
          propagation_timeout 2m
        }
      }
      route {
        @storage {
          host ente-storage.nuc.guion.io
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
          @${id} host ${id}.nuc.guion.io
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
    runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.iproute2 config.services.caddy.package];
    text = builtins.readFile ../../scripts/prepare-vpn-https;
  };
  prepareCommand =
    if haveToken
    then "${prepare}/bin/prepare-vpn-https ${token} ${vpnConfig} /run/caddy/vpn/https.caddy"
    else "${pkgs.coreutils}/bin/rm -f /run/caddy/vpn/https.caddy";
in {
  networking.hosts."127.0.0.1" = lib.mapAttrsToList (id: _: "${id}.localhost") localRoutes;

  services.caddy = {
    enable = true;
    package = caddy;
    globalConfig = ''
      auto_https disable_redirects
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
  # Only the runtime credential path appears in public configuration.
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
