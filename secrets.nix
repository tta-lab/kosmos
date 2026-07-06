let
  neil = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTS0VvV+hCQspIjDVn2o2NU/tTQ9b0h4xfAwWIgUdv9 neil@kosmos-wsl agenix";
  kosmosWsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEb+EzakYlcU0cEv1YmhY8D0VuI3UCpnLUk0qZEU53Kv root@nixos";
  users = [neil];
  systems = [kosmosWsl];
in {
  "secrets/ttal.env.age".publicKeys = users ++ systems;
  "secrets/kube-config.age".publicKeys = users ++ systems;
  "secrets/ttal-kubeconfig.age".publicKeys = users ++ systems;
  "secrets/sops-age-keys.age".publicKeys = users ++ systems;
  "secrets/frpc-env.age".publicKeys = users ++ systems;
  "secrets/env.age".publicKeys = users ++ systems;
  "secrets/mihomo-config.age".publicKeys = users ++ systems;
  "secrets/tuwunel-registration-token.age".publicKeys = users ++ systems;
  "secrets/cloudflared-kepos-credentials.age".publicKeys = users ++ systems;
  "secrets/forgejo-smoke-token.age".publicKeys = users ++ systems;
  "secrets/woodpecker-server-env.age".publicKeys = users ++ systems;
  "secrets/woodpecker-agent-env.age".publicKeys = users ++ systems;
}
