let
  kosmosWsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEb+EzakYlcU0cEv1YmhY8D0VuI3UCpnLUk0qZEU53Kv root@nixos";
in {
  "ttal.env.age".publicKeys = [kosmosWsl];
  "lenos-config.json.age".publicKeys = [kosmosWsl];
  "kube-config.age".publicKeys = [kosmosWsl];
}
