# Navidrome

Navidrome serves Neil's local music library on the WSL host. It is not exposed
through the `kepos` Cloudflare Tunnel.

The WSL module is `modules/wsl/navidrome.nix`.

Current settings:

- Music library: `/home/neil/music`
- Local bind: `127.0.0.1:4533`
- Public route: none
- Downloads: disabled
- Public shares: disabled

Create the music directory before adding music:

```bash
mkdir -p /home/neil/music
```

After switching the NixOS configuration, create the first admin user in the
browser from the host:

```text
http://127.0.0.1:4533
```

Then add friend accounts from the Navidrome admin UI. Friends can use the web UI
or any Subsonic-compatible client.

Check the service:

```bash
systemctl status navidrome
curl http://127.0.0.1:4533
```
