let
  neil = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTS0VvV+hCQspIjDVn2o2NU/tTQ9b0h4xfAwWIgUdv9 neil@kosmos-wsl agenix";
  kosmosWsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEb+EzakYlcU0cEv1YmhY8D0VuI3UCpnLUk0qZEU53Kv root@nixos";
  users = [neil];
  systems = [kosmosWsl];
in {
  "ttal.env.age".publicKeys = users ++ systems;
  "kube-config.age".publicKeys = users ++ systems;
  "sops-age-keys.age".publicKeys = users ++ systems;
}
