{
  agenix,
  pkgs,
  ...
}: let
  secretsDir = ../../secrets;
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
    secrets = {
      ttal-env = userSecret "ttal.env.age" "/home/neil/.config/ttal/.env";
      kube-config = userSecret "kube-config.age" "/home/neil/.kube/config";
    };
  };

  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
  ];

  systemd.tmpfiles.rules = [
    "d /home/neil/.config/ttal 0700 neil users -"
    "d /home/neil/.kube 0700 neil users -"
  ];
}
