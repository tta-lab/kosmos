# Listen Together

Listen Together is the shared playback coordinator for Kepos music rooms.

It works with the existing Navidrome server at `https://music.guion.io`.
Friends need Navidrome accounts before joining rooms. There is no second account
system for the listen-together layer.

The WSL module is `modules/wsl/listen-together.nix`.

Current settings:

- Local service: `127.0.0.1:4040` through cloudflared
- Public route: `https://party.guion.io`
- Allowed music server: `https://music.guion.io`
- Browser origins: `https://party.guion.io`, `https://music.guion.io`
- Room cap: 20 rooms
- Member cap: 12 members per room
- Stats endpoint: disabled

The service is `alsoGAMER/listen-together`, packaged as a native NixOS systemd
service rather than Docker. It has no database and no disk state. Rooms are kept
in memory, so a restart clears active rooms but does not affect Navidrome users,
music, playlists, or playback history.

The Cloudflare route is:

```text
https://party.guion.io -> cloudflared kepos tunnel -> http://127.0.0.1:4040
```

The service only validates credentials against the Kepos Navidrome instance:

```text
LT_ALLOWED_SERVERS=https://music.guion.io
```

This avoids running an open relay for arbitrary Subsonic servers.

After switching the NixOS configuration, check the service:

```bash
systemctl status listen-together
curl http://127.0.0.1:4040/healthz
systemctl status cloudflared-tunnel-kepos
```

Create the Cloudflare DNS route once:

```bash
cloudflared tunnel route dns nuc-wsl party.guion.io
```

Desktop clients can use the listen-together author's Feishin fork first. Mobile
support should come later from a Navic fork if the desktop proof works well.
