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

## Queue Control Boundary

Queue control should be centered on Navidrome, not on Feishin.

Feishin has a remote control server, but it is a player remote: it is suitable
for play, pause, seek, volume, rating, and similar playback controls. It is not
a stable shared queue API for searching songs, adding tracks, replacing queues,
or letting friends vote on what plays next.

Navidrome is the better boundary for shared listening because it already owns:

- the music library
- user accounts
- track IDs
- playlists
- Subsonic/OpenSubsonic compatibility
- the server-side play queue surface that Feishin can sync with

The listen-together layer should therefore treat Navidrome as the source of
truth for music identity and queue writes. Feishin, Navic, or any other client
should remain replaceable playback frontends.

Target shape:

- Friends log in with Navidrome accounts.
- A room service searches Navidrome/OpenSubsonic, not local Feishin state.
- Queue operations write Navidrome track IDs.
- Desktop clients test first with the listen-together Feishin fork.
- Mobile support can later use a Navic fork against the same room and Navidrome
  queue model.

This keeps the hard part in one place. If Feishin's own remote API grows a full
queue API later, it can be an optimization for that client, not the core system
contract.

## Next Steps

After deploying the WSL configuration, verify the local service and public route:

```bash
systemctl status listen-together
curl http://127.0.0.1:4040/healthz
systemctl status cloudflared-tunnel-kepos
curl https://party.guion.io/healthz
```

If the public route fails but the local health check works, restart the tunnel:

```bash
sudo systemctl restart cloudflared-tunnel-kepos
```

Then test the desktop client path with the listen-together Feishin fork:

```text
Music server: https://music.guion.io
Listen Together server: https://party.guion.io
```

In Feishin Web, open `https://player.guion.io`, then check Settings -> Playback.
New browser profiles should already have Listen Together enabled and pointed at
`https://party.guion.io`. Existing browser profiles may keep older persisted
settings; turn on Listen Together there if the player-bar room control is not
visible.

Use two Navidrome users for the first proof. Check:

- both users can log in
- one user can create a room
- the second user can join the room
- play, pause, seek, next track, and queue changes sync
- reconnect works after closing and reopening the client

Only start the mobile Navic fork after this desktop proof works.
