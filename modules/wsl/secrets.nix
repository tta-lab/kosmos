{
  agenix,
  config,
  lib,
  pkgs,
  ...
}: let
  secretsDir = ../../secrets;
  haveForgejoSmokeToken = builtins.pathExists (secretsDir + "/forgejo-smoke-token.age");
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
in {
  age = {
    identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets =
      {
        ttal-env = userSecret "ttal.env.age" "/home/neil/.config/ttal/.env";
        kube-config = userSecret "kube-config.age" "/home/neil/.kube/config";
        ttal-kubeconfig = userSecret "ttal-kubeconfig.age" "/home/neil/.ttal/kubeconfig";
        sops-age-keys = userSecret "sops-age-keys.age" "/home/neil/.config/sops/age/keys.txt";
        env = userSecret "env.age" "/home/neil/.config/env";
        woodpecker-server-env = {
          file = secretsDir + "/woodpecker-server-env.age";
          owner = "root";
          group = "root";
          mode = "0400";
          path = "/run/agenix/woodpecker-server-env";
        };
      }
      // lib.optionalAttrs haveForgejoSmokeToken {
        forgejo-smoke-token = userSecret "forgejo-smoke-token.age" "/home/neil/.config/kosmos/forgejo-smoke-token";
      };
  };

  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
  ];

  systemd.services.woodpecker-secret-sync = {
    description = "Synchronize the Woodpecker environment Secret to local K3s";
    wantedBy = ["multi-user.target"];
    wants = ["k3s.service"];
    after = ["k3s.service"];
    restartTriggers = [config.age.secrets.woodpecker-server-env.file];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = "${woodpeckerSecretSync}/bin/kosmos-sync-woodpecker-secret ${config.age.secrets.woodpecker-server-env.path}";
    };
  };
}
