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

The existing gateway delivers Shio's incoming Keet events to CFL production at
`http://127.0.0.1:3084/api/keet/events`. CFL accepts this route only from a
loopback peer and records accepted events before responding. This local webhook
URL belongs to the managed `keet-mcp.service` unit; the existing gateway
environment file retains its private MCP token and identity settings.

The same managed Serein unit sets
`KEET_WEBHOOK_URL=https://lamplit-keet.guion.io/api/keet/events` and reads
`/home/neil/.local/state/keet-mcp-serein/webhook.env` for
`KEET_WEBHOOK_BEARER_TOKEN`. This owner-only operator file uses the same value
as the Worker's `KEET_INGEST_TOKEN`; it is separate from `KEET_MCP_TOKEN` and
must not be committed. Keep the webhook URL in this module and the secret in
the environment file. Do not add a service drop-in for the webhook.

The existing `nuc-wsl` Cloudflare Tunnel routes `keet-serein.lamplit.run` to
Serein's loopback listener. The remote MCP endpoint is
`https://keet-serein.lamplit.run/mcp`; retained images use the same host under
`/images/{ref}`. Both routes require Serein's existing `KEET_MCP_TOKEN` as an
`Authorization: Bearer` header on every request. Store that token only in the
Cloudflare Agent's secret store when configuring its MCP client. This route
does not use a Cloudflare Access service token. Do not copy the webhook bearer
token here: it authenticates the opposite, KFA-to-Agent direction.

The former MCP hostname was `serein-keet.guion.io`. Activate the current route
using the [public hostname procedure](matrix-mcp-remote.md#public-hostname-activation);
the `lamplit-keet.guion.io` webhook target remains unchanged. Cloudflare client
URL changes and authenticated verification belong to the operator.

Serein uses the verified runtime copy at
`/home/neil/.local/share/keet-runtime/4.22.0-linux-x64` and private identity,
state, and workspace directories under
`/home/neil/.local/state/keet-mcp-serein`. The runtime directory must contain
`bare`, `core-worker.bundle`, and the full `node_modules` tree with the 25
native addons selected by the bundle manifest. Copying only the two top-level
files causes `Keet native-addon closure is incomplete` on startup. The avatar
from `pi-on-cf/frontend/static/avatars/jiji-v2.png` is available at
`/home/neil/.local/share/keet-mcp-serein/avatar.png`, but is not applied to
the Keet profile. The separate `lamplit-keet.guion.io` Worker hostname admits
only `/api/keet/events` and checks the webhook bearer before processing an
event; the main `lamplit-cf.guion.io` site remains behind Cloudflare Access.

## One-time unit handoff

Historical initial setup procedure. Do not repeat this unit/identity handoff
when changing the public MCP hostname.

At initial setup, `/home/neil/.config/systemd/user/keet-mcp.service` was a
regular, unmanaged file. Home Manager could not replace it automatically. The
original handoff required building the WSL closure, then moving that file to a backup
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

After Serein's gateway has created its identity, stop only its unit to set the
display name through KFA's human setup CLI, then restart it:

```sh
systemctl --user stop keet-mcp-serein.service
KEET_MCP_RUNTIME_DIR=/home/neil/.local/share/keet-runtime/4.22.0-linux-x64 \
KEET_MCP_IDENTITY_DIR=/home/neil/.local/state/keet-mcp-serein/identity \
  /run/current-system/sw/bin/node \
  /home/neil/code/projects/lamplitisles/keet-for-agent/packages/keet-mcp/dist/setup.js \
  profile --display-name Serein
systemctl --user start keet-mcp-serein.service
```

The setup CLI does not need the MCP token. The gateway discovers newly joined
rooms only at startup, so restart that specific unit after later room setup.

To join a group as Serein, paste its invitation only at the hidden terminal
prompt. This keeps the invitation out of shell arguments, history, files, and
logs, and restarts her gateway even if joining fails:

```sh
(
  set -e
  trap 'systemctl --user start keet-mcp-serein.service' EXIT
  systemctl --user stop keet-mcp-serein.service
  read -r -s -p 'Keet invitation: ' invitation
  printf '\n'
  printf '%s' "$invitation" | \
    KEET_MCP_RUNTIME_DIR=/home/neil/.local/share/keet-runtime/4.22.0-linux-x64 \
    KEET_MCP_IDENTITY_DIR=/home/neil/.local/state/keet-mcp-serein/identity \
    /run/current-system/sw/bin/node \
    /home/neil/code/projects/lamplitisles/keet-for-agent/packages/keet-mcp/dist/setup.js join
)
```
