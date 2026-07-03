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
cloudflared tunnel create nuc-wsl
cloudflared tunnel route dns nuc-wsl kepos.guion.io
```

Encrypt the tunnel credentials JSON. Replace `<uuid>` with the tunnel UUID from
the `cloudflared tunnel create` output:

```bash
agenix -e secrets/cloudflared-kepos-credentials.age < ~/.cloudflared/<uuid>.json
```

Create a registration token:

```bash
age-keygen -o /tmp/kepos-registration-key
sed -n 's/^# public key: //p' /tmp/kepos-registration-key | agenix -e secrets/tuwunel-registration-token.age
rm /tmp/kepos-registration-key
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

## Registration Token

Registration is token-gated:

- `allow_registration = true`
- `registration_token_file = "/run/credentials/tuwunel.service/registration-token"`

Anyone with the token can register an account. Treat it like an invite code for
friends, not like a public link.

To rotate the token, replace the encrypted secret and rebuild:

```bash
age-keygen -o /tmp/kepos-registration-key
sed -n 's/^# public key: //p' /tmp/kepos-registration-key | agenix -e secrets/tuwunel-registration-token.age
rm /tmp/kepos-registration-key
git add secrets/tuwunel-registration-token.age
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" nixos-rebuild switch --flake .#wsl
```

To stop new registrations, set `allow_registration = false` in
`modules/wsl/kepos-matrix.nix` and rebuild. Existing accounts keep working.

## Encryption

Kepos currently sets `allow_encryption = false`. Rooms created on this server are
not end-to-end encrypted, so messages are stored by the homeserver in readable
form. This is intentional for the first friend/agent workspace because it keeps
agent access and debugging simple. Do not use this deployment for private
messages that need E2EE unless this setting is changed first.
