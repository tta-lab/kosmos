# Feishin Web

Feishin Web is a prettier browser client for the existing Navidrome server.

- Public URL: `https://player.guion.io`
- Local service: `127.0.0.1:9180`
- Music server: `https://music.guion.io`
- Source fork: `alsoGAMER/feishin`, commit `1961f14e063ddbe568c9ec6e815753d22d60f1e4`
- WSL module: `modules/wsl/feishin-web.nix`

The service is built as static web assets with Nix and served by
`static-web-server`. It does not use Docker or Podman.

`player.guion.io` goes through the existing `nuc-wsl` Cloudflare tunnel:

```text
https://player.guion.io -> cloudflared kepos tunnel -> http://127.0.0.1:9180
```

The generated web config locks the default server to Navidrome:

```text
SERVER_NAME=Kepos Music
SERVER_TYPE=navidrome
SERVER_URL=https://music.guion.io
SERVER_LOCK=true
```

After the first deploy, create the Cloudflare DNS route if it does not already
exist:

```bash
cloudflared tunnel route dns nuc-wsl player.guion.io
```

Smoke test:

```bash
systemctl status feishin-web
curl -I http://127.0.0.1:9180
curl -fsS http://127.0.0.1:9180/settings.js
systemctl status cloudflared-tunnel-kepos
```
