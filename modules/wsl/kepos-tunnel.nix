{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.keposTunnel;
  cloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveCredentials = builtins.pathExists cloudflaredCredentialsFile;
in {
  options.kosmos.wsl.keposTunnel.enable = lib.mkEnableOption "Kepos Cloudflare tunnel";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveCredentials) [
        ''
          The Kepos Cloudflare tunnel is enabled but its age secret is missing.
          Create secrets/cloudflared-kepos-credentials.age, then rebuild.
        ''
      ];
    }

    (lib.mkIf haveCredentials {
      age.secrets.cloudflared-kepos-credentials = {
        file = cloudflaredCredentialsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      services.cloudflared = {
        enable = true;

        tunnels.kepos = {
          credentialsFile = config.age.secrets.cloudflared-kepos-credentials.path;
          default = "http_status:404";
          ingress."approve.guion.io" = "http://127.0.0.1:17480";
        };
      };

      systemd.services.cloudflared-tunnel-kepos.environment.TUNNEL_TRANSPORT_PROTOCOL = "http2";
    })
  ]);
}
