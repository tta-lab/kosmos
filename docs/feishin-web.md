# Feishin Web

Feishin Web is a prettier browser client for the existing Navidrome server.

- Public URL: none
- Local service: `127.0.0.1:9180`
- Music server: `https://music.guion.io`
- Listen Together server: `https://party.guion.io`
- Source fork: `alsoGAMER/feishin`, commit `1961f14e063ddbe568c9ec6e815753d22d60f1e4`
- WSL module: `modules/wsl/feishin-web.nix`

The service is built as static web assets with Nix and served by
`static-web-server`. It does not use Docker or Podman.

The service is local-only and has no `kepos` Cloudflare Tunnel ingress.

The generated web config locks the default server to Navidrome:

```text
SERVER_NAME=Kepos Music
SERVER_TYPE=subsonic
SERVER_URL=https://music.guion.io
SERVER_LOCK=true
LISTEN_TOGETHER_URL=https://party.guion.io
LISTEN_TOGETHER_ENABLED=true
```

New browser profiles default the Listen Together client to enabled with the
Kepos sidecar URL. Existing browser profiles may keep their persisted playback
settings; enable it manually in Feishin under Settings -> Playback and set:

```text
Listen Together server=https://party.guion.io
```

Smoke test:

```bash
systemctl status feishin-web
curl -I http://127.0.0.1:9180
curl -fsS http://127.0.0.1:9180/settings.js
```
