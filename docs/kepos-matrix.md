# Kepos Matrix

Kepos runs Tuwunel as the Matrix homeserver for `kepos.guion.io` and exposes it
through a Cloudflare Tunnel from kosmos-wsl.

The Nix module is `modules/wsl/kepos-matrix.nix`. It stays inactive until both
age secret files exist:

- `secrets/tuwunel-registration-token.age`
- `secrets/cloudflared-kepos-credentials.age`

Create the Cloudflare Tunnel and route:

```bash
cloudflared tunnel login
cloudflared tunnel create kepos
cloudflared tunnel route dns kepos kepos.guion.io
```

Encrypt the tunnel credentials JSON. Replace `<uuid>` with the tunnel UUID from
the `cloudflared tunnel create` output:

```bash
agenix -e secrets/cloudflared-kepos-credentials.age < ~/.cloudflared/<uuid>.json
```

Create a registration token:

```bash
openssl rand -base64 32 | agenix -e secrets/tuwunel-registration-token.age
```

Stage the encrypted files so Nix flakes can see them:

```bash
git add secrets/cloudflared-kepos-credentials.age secrets/tuwunel-registration-token.age
```

Then rebuild:

```bash
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" nixos-rebuild switch --flake .#wsl
```

Check the services:

```bash
systemctl status tuwunel
systemctl status cloudflared-tunnel-kepos
curl http://127.0.0.1:6167/_matrix/client/versions
```
