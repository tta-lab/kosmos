# Retired Aru adapters for CFL

Spec #4334 retires both dedicated `aru-cfl-dev` and `aru-cfl-prod` Home Manager
services and their `aru-dev.lamplit.run` → loopback 8787 and `aru.lamplit.run` →
loopback 8788 tunnel routes. The old install/start/pairing instructions are retired.
The actual CFL services remain on 3082/3083/3084, including Shio prod. Post uses
5140/18787; it does not replace Aru on either old port.

Only these two adapter deployments are removed. The shared Cloudflare tunnel,
its Keet and Matrix routes, credentials, HTTP2 transport and final 404 remain.
Kepos peer policy and Caddy contain no dedicated Aru route. Acrylic's remote
8787 and the cluster codex-bridge's 8787/8788 are unrelated and remain.
No dedicated Aru timer or scheduler was found.

Implementation does not stop services. At Orc's reviewed activation, expect both
Aru units to stop/disappear, with no remaining Aru listener on 8787/8788. Inspect
actual port owners before making that claim. Changing the shared tunnel config
may restart its connector and briefly interrupt Matrix/Keet public traffic;
coordinate this window and verify their routes and health afterward. Do not
restart CFL, Matrix or Keet application units for this retirement. See the
[combined Post/Shio handoff](post-console.md) for fresh baselines and dry-activate.

Retain `~/.local/share/aru-cfl-{dev,prod}` and
`~/.local/state/aru-cfl-{dev,prod}` unchanged, including releases, config,
identity, grants, SQLite, staged images, credentials and private pairing logs.
Agents must not inspect their plaintext. No cleanup, migration or history replay
is part of retirement. Existing phone clients lose these retired endpoints;
no replacement or automatic migration is claimed. External DNS records are not
modified; the retained tunnel's catch-all handles these unmatched names.
Cloudflare documents [local ingress validation and rule matching](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/configuration-file/);
validate the generated config and check the two retired names against its final
404 rule without opening the referenced credentials file.

Rollback restores the saved system/Home Manager generation and prior tunnel
configuration after reviewing the entire activation plan, then restores only the
prior Aru service availability against the retained installations/state. Preserve
all Post/CFL state and histories; do not copy or roll back databases. Never replay
an unknown admission or resend an uncertain operation. Do not rerun obsolete
installation or pairing steps as rollback.
