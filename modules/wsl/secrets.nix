{
  agenix,
  config,
  lib,
  pkgs,
  ...
}: let
  secretsDir = ../../secrets;
  haveForgejoSmokeToken = builtins.pathExists (secretsDir + "/forgejo-smoke-token.age");
  haveSonioxKey = builtins.pathExists (secretsDir + "/soniox-key.age");
  haveVolcengineKey = builtins.pathExists (secretsDir + "/volcengine-key.age");
  userSecret = fileName: path: {
    file = secretsDir + "/${fileName}";
    owner = "neil";
    group = "users";
    mode = "0400";
    inherit path;
  };
  woodpeckerSecretSync = pkgs.writeShellApplication {
    name = "kosmos-sync-woodpecker-secret";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ../../scripts/sync-woodpecker-secret;
  };
  enteSecretSync = pkgs.writeShellApplication {
    name = "kosmos-sync-ente-secret";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ../../scripts/sync-ente-secret;
  };
  ankiSecretSync = pkgs.writeShellApplication {
    name = "kosmos-sync-anki-secret";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ../../scripts/sync-anki-secret;
  };
  hindsightSecretSync = pkgs.writeShellApplication {
    name = "kosmos-sync-hindsight-secret";
    runtimeInputs = [pkgs.kubectl];
    text = builtins.readFile ../../scripts/sync-hindsight-secret;
  };
  cloudreveSecretSync = pkgs.writeShellApplication {
    name = "kosmos-sync-cloudreve-secret";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.kubectl
    ];
    text = builtins.readFile ../../scripts/sync-cloudreve-secret;
  };
in {
  age = {
    identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets =
      {
        ttal-env = userSecret "ttal.env.age" "/home/neil/.config/ttal/.env";
        kube-config = userSecret "kube-config.age" "/home/neil/.kube/config";
        sops-age-keys = userSecret "sops-age-keys.age" "/home/neil/.config/sops/age/keys.txt";
        env = userSecret "env.age" "/home/neil/.config/env";
        woodpecker-server-env = {
          file = secretsDir + "/woodpecker-server-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/woodpecker-server-env";
        };
        woodpecker-postgres-env = {
          file = secretsDir + "/woodpecker-postgres-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/woodpecker-postgres-env";
        };
        ente-stack-env = {
          file = secretsDir + "/ente-stack-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/ente-stack-env";
        };
        anki-sync-env = {
          file = secretsDir + "/anki-sync-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/anki-sync-env";
        };
        hindsight-env = {
          file = secretsDir + "/hindsight-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/hindsight-env";
        };
        cloudreve-env = {
          file = secretsDir + "/cloudreve-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/cloudreve-env";
        };
        openvpn-config = {
          file = secretsDir + "/openvpn-config.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/openvpn-config";
        };
        openvpn-auth = {
          file = secretsDir + "/openvpn-auth.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/openvpn-auth";
        };
        # OpenClaw secrets: committed .age files exist, so declare directly.
        openclaw-gateway-token = userSecret "openclaw-gateway-token.age" "/home/neil/.config/openclaw/gateway-token";
        openclaw-telegram-token = userSecret "openclaw-telegram-token.age" "/home/neil/.config/openclaw/telegram-token";
        openclaw-deepseek-key = userSecret "openclaw-deepseek-key.age" "/home/neil/.config/openclaw/deepseek-key";
        openclaw-miniflux-password = userSecret "openclaw-miniflux-password.age" "/home/neil/.config/openclaw/miniflux-password";
      }
      # Soniox key: declared only once the .age file exists (agenix build
      # fails on missing secret files), same pattern as forgejo-smoke-token.
      # Create it with: agenix -e secrets/soniox-key.age
      // lib.optionalAttrs haveSonioxKey {
        soniox-key = userSecret "soniox-key.age" "/home/neil/.config/openclaw/soniox-key";
      }
      # Volcengine (豆包) TTS key: same pattern.
      # Create it with: agenix -e secrets/volcengine-key.age
      // lib.optionalAttrs haveVolcengineKey {
        volcengine-key = userSecret "volcengine-key.age" "/home/neil/.config/openclaw/volcengine-key";
      }
      // lib.optionalAttrs haveForgejoSmokeToken {
        forgejo-smoke-token = userSecret "forgejo-smoke-token.age" "/home/neil/.config/kosmos/forgejo-smoke-token";
      };
  };

  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
  ];

  systemd.services = {
    woodpecker-secret-sync = {
      description = "Synchronize the Woodpecker environment Secret to local K3s";
      wantedBy = ["multi-user.target"];
      wants = ["k3s.service"];
      after = ["k3s.service"];
      restartTriggers = [
        config.age.secrets.woodpecker-server-env.file
        config.age.secrets.woodpecker-postgres-env.file
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${woodpeckerSecretSync}/bin/kosmos-sync-woodpecker-secret ${config.age.secrets.woodpecker-server-env.path} ${config.age.secrets.woodpecker-postgres-env.path}";
      };
    };
    ente-secret-sync = {
      description = "Synchronize the Ente environment Secret to local K3s";
      wantedBy = ["multi-user.target"];
      wants = ["k3s.service"];
      after = ["k3s.service"];
      restartTriggers = [config.age.secrets.ente-stack-env.file];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${enteSecretSync}/bin/kosmos-sync-ente-secret ${config.age.secrets.ente-stack-env.path}";
      };
    };
    anki-secret-sync = {
      description = "Synchronize the Anki environment Secret to local K3s";
      wantedBy = ["multi-user.target"];
      wants = ["k3s.service"];
      after = ["k3s.service"];
      restartTriggers = [config.age.secrets.anki-sync-env.file];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${ankiSecretSync}/bin/kosmos-sync-anki-secret ${config.age.secrets.anki-sync-env.path}";
      };
    };
    hindsight-secret-sync = {
      description = "Synchronize the Hindsight environment Secret to local K3s";
      wantedBy = ["multi-user.target"];
      wants = ["k3s.service"];
      after = ["k3s.service"];
      restartTriggers = [config.age.secrets.hindsight-env.file];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${hindsightSecretSync}/bin/kosmos-sync-hindsight-secret ${config.age.secrets.hindsight-env.path}";
      };
    };
    cloudreve-secret-sync = {
      description = "Synchronize the Cloudreve environment Secret to local K3s";
      wantedBy = ["multi-user.target"];
      wants = ["k3s.service"];
      after = ["k3s.service"];
      restartTriggers = [config.age.secrets.cloudreve-env.file];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${cloudreveSecretSync}/bin/kosmos-sync-cloudreve-secret ${config.age.secrets.cloudreve-env.path}";
      };
    };
  };
}
