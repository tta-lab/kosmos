# FlickGrove on ko

FlickGrove is Neil's Home Manager user service `flickgrove.service`. ko runs an
independent Peer; Mac and Pixel 7a visit `http://flickgrove.localhost:17480`
through Kepos. The service listens on `127.0.0.1:4318`; Kepos allows these two
devices. Every Peer serves the frontend and owns its local session trees.
Browsers connect directly to each configured Peer; ko does not relay remote
business calls. Configure additional Peers and their access credentials in
each browser's Settings → Hosts. Preserve WebSocket upgrades and
`Sec-WebSocket-Protocol` through proxies.

It uses Nix's `/run/current-system/sw/bin/bun`, the existing Codex login and og
project registry. Host-local MCP is configured automatically for its sessions.
Neil's user linger is enabled.

- Runtime source: `~/code/projects/lamplitisles/experiments` (local checkout).
- Persistent state: `~/.local/share/flickgrove` (SQLite and private identity
  credentials; preserve this directory).
- Unit source: `modules/wsl/flickgrove.nix`.

## Upgrade

Update and build the local checkout, then start the service:

```bash
systemctl --user stop flickgrove.service
cd ~/code/projects/lamplitisles/experiments
og pull
bun install --frozen-lockfile
bun run --cwd flickgrove build
systemctl --user start flickgrove.service
```

Stop before replacing runtime files. Upgrades interrupt active local turns;
the next explicit message resumes the durable thread. If only rebuilding
unchanged source, run `bun run --cwd flickgrove build` and
`systemctl --user restart flickgrove.service`.

Application upgrades do not require a NixOS rebuild. Changes to the unit need
`nh os switch . -H wsl` from Kosmos; Kepos policy changes need
`just kepos-policy-render`. Initial preparation and recovery details are in
FlickNote #3141. For rollback, build a previous reviewed commit; verify state
compatibility before opening newer data with older code.

## Status and logs

```bash
systemctl --user status flickgrove.service
journalctl --user -u flickgrove.service -f
curl --fail -H 'Host: flickgrove.localhost:17480' \
  http://127.0.0.1:4318/
```
