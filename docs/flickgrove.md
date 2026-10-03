# FlickGrove on ko

FlickGrove is Neil's Home Manager user service `flickgrove.service`. ko runs the
fixed Hub; Mac visits `http://flickgrove.localhost:17480` through Kepos. The
service listens on `127.0.0.1:4318`, with a Mac-only ACL.

It uses Nix's `/run/current-system/sw/bin/bun`, the existing Codex login and og
project registry. Host-local MCP is configured automatically for its sessions.
Neil's user linger is enabled.

- Runtime source: `~/.local/share/flickgrove-runtime` (detached worktree of
  `~/code/projects/lamplitisles/experiments`; keep the parent checkout).
- Persistent state: `~/.local/share/flickgrove` (SQLite and private identity
  credentials; preserve this directory).
- Unit source: `modules/wsl/flickgrove.nix`.

## Upgrade

Update the experiments checkout with `og pull`, then deploy a reviewed commit:

```bash
systemctl --user stop flickgrove.service
cd ~/.local/share/flickgrove-runtime
git switch --detach <reviewed-commit>
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
  http://127.0.0.1:4318/api/snapshot
```
