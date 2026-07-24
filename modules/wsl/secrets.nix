{
  agenix,
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
}
