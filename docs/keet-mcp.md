# Keet MCP gateways on WSL

`modules/wsl/keet-mcp.nix` owns two Home Manager user services. Both run the
gateway built in `/home/neil/code/projects/lamplitisles/keet-for-agent` and
use separate Keet identities. Keep the KFA checkout built before restarting
either unit. Keet's pinned 4.22.0 Linux x64 runtime is operator supplied outside
the package.

| Unit | Identity and state | MCP listener | Secret source |
| --- | --- | --- | --- |
| `keet-mcp.service` | Existing retired DSH identity and state | Existing `gateway.env` setting | `/home/neil/.local/state/keet-mcp/gateway.env` |
| `keet-mcp-serein.service` | `/home/neil/.local/state/keet-mcp-serein/{identity,state}` | `127.0.0.1:8767` | Agenix `keet-mcp-serein.env` |

The existing gateway's environment file remains a local operator secret. This
change moves ownership of its **unit** to Home Manager; it does not read or
rewrite the identity, state, or secret file. Serein's encrypted secret contains
only `KEET_MCP_TOKEN=<at least 32 characters>`. To rotate it, run
`agenix -e secrets/keet-mcp-serein.env.age` in this checkout and retain that
single-line format. The key must never be placed in a Nix string or URL.

Serein uses the verified runtime copy at
`/home/neil/.local/share/keet-runtime/4.22.0-linux-x64`, private identity,
state, and workspace directories under
`/home/neil/.local/state/keet-mcp-serein`, and the avatar at
`/home/neil/.local/share/keet-mcp-serein/avatar.png`. Her avatar is copied from
`pi-on-cf/frontend/static/avatars/jiji-v2.png` on the Mac. No webhook URL is
configured yet because `pi-on-cf` has no Keet webhook receiver route. Starting
the gateway exposes its loopback MCP endpoint but does not wake the Cloudflare
Agent on incoming Keet messages.

## One-time unit handoff

The existing `/home/neil/.config/systemd/user/keet-mcp.service` is currently a
regular, unmanaged file. Home Manager will not replace it automatically. After
this PR merges, build the WSL closure first, then move that file to a backup
outside `~/.config`, switch, and verify both units:

```sh
cd /home/neil/code/projects/tta-lab/kosmos
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
mv /home/neil/.config/systemd/user/keet-mcp.service \
  /home/neil/.local/state/keet-mcp/keet-mcp.service.before-home-manager
nh os switch . -H wsl
systemctl --user daemon-reload
systemctl --user enable --now keet-mcp.service keet-mcp-serein.service
systemctl --user is-active keet-mcp.service keet-mcp-serein.service
```

The original gateway remains running while its unit file is moved. If the
switch fails, move the backup back to its original path and reload the user
daemon before retrying. Do not alter the existing `gateway.env` or delete a
Keet identity lock file.

After Serein's gateway has created its identity, stop only its unit to apply
the display name and avatar through KFA's human setup CLI, then restart it:

```sh
systemctl --user stop keet-mcp-serein.service
KEET_MCP_RUNTIME_DIR=/home/neil/.local/share/keet-runtime/4.22.0-linux-x64 \
KEET_MCP_IDENTITY_DIR=/home/neil/.local/state/keet-mcp-serein/identity \
  /run/current-system/sw/bin/node \
  /home/neil/code/projects/lamplitisles/keet-for-agent/packages/keet-mcp/dist/setup.js \
  profile --display-name Serein \
  --avatar /home/neil/.local/share/keet-mcp-serein/avatar.png
systemctl --user start keet-mcp-serein.service
```

The setup CLI does not need the MCP token. The gateway discovers newly joined
rooms only at startup, so restart that specific unit after later room setup.
