let
  neil = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTS0VvV+hCQspIjDVn2o2NU/tTQ9b0h4xfAwWIgUdv9 neil@kosmos-wsl agenix";
  kosmosWsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEb+EzakYlcU0cEv1YmhY8D0VuI3UCpnLUk0qZEU53Kv root@nixos";
  users = [neil];
  systems = [kosmosWsl];
in {
  "secrets/ttal.env.age".publicKeys = users ++ systems;
  "secrets/kube-config.age".publicKeys = users ++ systems;
  "secrets/sops-age-keys.age".publicKeys = users ++ systems;
  "secrets/frpc-env.age".publicKeys = users ++ systems;
  "secrets/env.age".publicKeys = users ++ systems;
  "secrets/cloudflared-kepos-credentials.age".publicKeys = users ++ systems;
  "secrets/forgejo-smoke-token.age".publicKeys = users ++ systems;
  "secrets/woodpecker-server-env.age".publicKeys = users ++ systems;
  "secrets/ente-stack-env.age".publicKeys = users ++ systems;
  "secrets/anki-sync-env.age".publicKeys = users ++ systems;
  "secrets/hindsight-env.age".publicKeys = users ++ systems;
  "secrets/openvpn-config.age".publicKeys = users ++ systems;
  "secrets/openvpn-auth.age".publicKeys = users ++ systems;
  "secrets/openclaw-gateway-token.age".publicKeys = users ++ systems;
  "secrets/openclaw-telegram-token.age".publicKeys = users ++ systems;
}
