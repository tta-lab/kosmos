# Navidrome

Navidrome serves Neil's local music library at `https://music.guion.io`.

The WSL module is `modules/wsl/navidrome.nix`.

Current settings:

- Music library: `/home/neil/music`
- Local bind: `127.0.0.1:4533`
- Public route: `music.guion.io` through the existing `nuc-wsl` Cloudflare Tunnel
- Downloads: disabled
- Public shares: disabled

Create the music directory before adding music:

```bash
mkdir -p /home/neil/music
```

After switching the NixOS configuration, create the first admin user in the
browser:

```text
https://music.guion.io
```

Then add friend accounts from the Navidrome admin UI. Friends can use the web UI
or any Subsonic-compatible client.

The Cloudflare DNS route is external state. Create it once:

```bash
cloudflared tunnel route dns nuc-wsl music.guion.io
```

Check the service:

```bash
systemctl status navidrome
curl http://127.0.0.1:4533
```
