# Jellyfin

Jellyfin is an experimental full-media server for Kepos at `https://media.guion.io`.

The WSL module is `modules/wsl/jellyfin.nix`.

Current settings:

- Public route: `media.guion.io` through the existing `nuc-wsl` Cloudflare Tunnel
- Local service: Jellyfin default HTTP port `8096`
- Media library: `/home/neil/media`
- Music library: `/home/neil/music`
- Service user: `neil:users`
- Firewall: not opened by NixOS

The service runs as `neil` because the media folders are under `/home/neil`.

Create or populate media folders:

```bash
mkdir -p /home/neil/media /home/neil/music
```

After switching the NixOS configuration, open:

```text
https://media.guion.io
```

Create the first Jellyfin admin user in the browser, then add libraries:

- Music: `/home/neil/music`
- Movies or mixed media: `/home/neil/media`

The Cloudflare DNS route is external state. Create it once:

```bash
cloudflared tunnel route dns nuc-wsl media.guion.io
```

Check the service:

```bash
systemctl status jellyfin
curl http://127.0.0.1:8096
```
