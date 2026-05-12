{
  agenix,
  lib,
  pkgs,
  ...
}: let
  secretsDir = ../../secrets;
  secretFile = name: secretsDir + "/${name}";
  optionalSecret = name: fileName: path:
    lib.optionalAttrs (builtins.pathExists (secretFile fileName)) {
      ${name} = {
        file = secretFile fileName;
        owner = "neil";
        group = "users";
        mode = "0400";
        inherit path;
      };
    };
in {
  age = {
    identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets =
      optionalSecret "ttal-env" "ttal.env.age" "/home/neil/.config/ttal/.env"
      // optionalSecret "lenos-config" "lenos-config.json.age" "/home/neil/.local/share/lenos/config.json"
      // optionalSecret "kube-config" "kube-config.age" "/home/neil/.kube/config";
  };

  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
  ];

  systemd.tmpfiles.rules = [
    "d /home/neil/.config/ttal 0700 neil users -"
    "d /home/neil/.local/share/lenos 0700 neil users -"
    "d /home/neil/.kube 0700 neil users -"
  ];
}
