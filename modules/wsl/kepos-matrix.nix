{
  config,
  lib,
  nixpkgs-unstable,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.keposMatrix;
  tuwunelRegistrationTokenFile = ../../secrets/tuwunel-registration-token.age;
  cloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveSecrets =
    builtins.pathExists tuwunelRegistrationTokenFile
    && builtins.pathExists cloudflaredCredentialsFile;
in {
  # This module is imported from the WSL flake configuration, which passes
  # nixpkgs-unstable through specialArgs so we can use the upstream Tuwunel
  # NixOS module before kosmos moves past 25.05.
  imports = [
    "${nixpkgs-unstable}/nixos/modules/services/matrix/tuwunel.nix"
  ];

  options.kosmos.wsl.keposMatrix.enable = lib.mkEnableOption "Kepos Matrix homeserver and Cloudflare tunnel";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveSecrets) [
        ''
          Kepos Matrix is enabled but required age secrets are missing.
          Create secrets/tuwunel-registration-token.age and secrets/cloudflared-kepos-credentials.age, then rebuild.
        ''
      ];
    }

    (lib.mkIf haveSecrets {
      age.secrets = {
        tuwunel-registration-token = {
          file = tuwunelRegistrationTokenFile;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        cloudflared-kepos-credentials = {
          file = cloudflaredCredentialsFile;
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };

      services.matrix-tuwunel = {
        enable = true;
        package = pkgsUnstable.matrix-tuwunel;

        settings.global = {
          server_name = "kepos.guion.io";
          address = ["127.0.0.1"];
          port = [6167];
          allow_registration = true;
          allow_federation = false;
          allow_encryption = false;
          registration_token_file = "/run/credentials/tuwunel.service/registration-token";

          well_known = {
            client = "https://kepos.guion.io";
            server = "kepos.guion.io:443";
          };
        };
      };

      systemd.services.tuwunel.serviceConfig.LoadCredential = [
        "registration-token:${config.age.secrets.tuwunel-registration-token.path}"
      ];

      services.cloudflared = {
        enable = true;

        tunnels.kepos = {
          credentialsFile = config.age.secrets.cloudflared-kepos-credentials.path;
          ingress."kepos.guion.io" = "http://127.0.0.1:6167";
          default = "http_status:404";
        };
      };

      systemd.services.cloudflared-tunnel-kepos.environment.TUNNEL_TRANSPORT_PROTOCOL = "http2";
    })
  ]);
}
