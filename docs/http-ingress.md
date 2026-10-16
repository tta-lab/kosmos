# HTTP access on kosmos-wsl

The host Caddy system service keeps `127.0.0.1:17480`, using the standard
NixOS Caddy package with a pinned Cloudflare provider and its dedicated non-root
account. With the runtime DNS credential and expected VPN address, it obtains
a wildcard certificate and serves HTTPS at `10.80.12.4:443` for all 20
`<id>.nuc.guion.io` authorities. There is no HTTP 80 or LAN listener. Unknown Host
names do not dispatch. See [VPN HTTPS](nuc-vpn-https.md) for the exact mappings,
source restrictions, certificate/DNS prerequisites and ordered activation.

- Host application routes live in `modules/wsl/http-gateway.nix`: `dev-her`
  (3082), `staging-her` (3083), `prod-lamplit` (3084), `flickgrove` (4318),
  `lamplit-post` (5140), and `mihomo-dashboard` (9090). Caddy preserves Host,
  path and query.
- `http/cluster-routes.json` owns cluster authorities and Service destinations.
  Each application's Tanka library owns its old and new Ingress authorities via
  `tanka/lib/ingress.libsonnet`. ERPNext's workload is managed separately;
  the devops environment owns only its Ingress.
- `tanka/lib/traefik.libsonnet` owns the HTTP-only controller, RBAC, and
  `cluster-http` ClusterIP Service. Its hostPort is **loopback-only 27480**;
  its in-cluster Service port is **17480**. The k3s bundled Traefik and
  ServiceLB remain disabled so they cannot create default public listeners.
- `tanka/lib/gateway.libsonnet` owns CoreDNS rewrites to the cluster entry.
  WebSocket and streaming HTTP use the proxies' native forwarding.

A new cluster application adds a registry entry and an Ingress in its own
library. Apply its environment and `just gateway-apply` for the DNS change,
then rebuild WSL to refresh the host Caddy's explicit host allowlist. No
catch-all route or NodePort is used. App deploy recipes apply their Ingresses;
Traefik watches changes without a controller restart.

## Deploy and check

Use the local cluster only:

```sh
just gateway-diff
just gateway-apply always
nh os switch . -H wsl
systemctl status caddy --no-pager
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n devops rollout status deployment/cluster-http
curl --noproxy '*' --fail -H 'Host: prod-lamplit.localhost:17480' http://127.0.0.1:17480/
curl --noproxy '*' -H 'Host: grafana.localhost:17480' -I http://127.0.0.1:17480/
```

Changing `http-gateway.nix` uses a NixOS switch; the standard module reloads
Caddy through its private Unix admin socket at `/run/caddy/admin.sock`.
The managed configuration is `/etc/caddy/caddy_config`.

For Mac SSH access, close Kepos App to release **Mac port 17480**, then replace
only the local forward in the existing SSH command with:

```sh
-L 17480:127.0.0.1:17480
```

Continue using the existing UU SSH destination and authentication. Mac's old
17481 forward can be removed. Existing `<service>.localhost:17480` routes
remain. Most applications keep
their old public URL settings and support both entries. FlickGrove is an
explicit single-Origin exception: after activation, update its Mac Peer
URL to `https://flickgrove.nuc.guion.io` and reuse the existing credential. Ente file
operations from old API clients also require VPN/public TLS trust; see the
[application-specific behavior](nuc-vpn-https.md#authorities-and-application-behavior).
NUC Kepos continues on `127.0.0.1:17481` and is independent of the Caddy listener. Dagger, SSH and the Mihomo proxy remain
raw TCP services with their own forwarding arrangements.

The Serein Keet Cloudflare Tunnel goes directly to 8767; the Organon MCP
Tunnel is independent. Neither depends on this ingress. The IPv6 HTTPS smoke,
its DDNS updater, custom Caddy image and credential synchronizer are retired.
The existing encrypted Cloudflare token is reused by host Caddy DNS-01; the
old certificate volume is retained for separate operator cleanup. This migration
does not delete cloud DNS or revoke tokens.

## First migration

Before taking port 17480 from the old Caddy Pod, deploy and validate Traefik
at 27480 and apply all application Ingresses. Save the old gateway's
Deployment, Service and ConfigMap plus `/run/current-system` outside Git.
Scale the old gateway to zero, switch NixOS, then verify each application and
an unknown host. HTTP requests and long connections can be interrupted during
this cutover. After acceptance, remove the old Deployment, Service and
ConfigMap explicitly; retain the certificate PVC and Secret for operator
cleanup. No migration or resource deletion runs during Nix activation.

Rollback uses the saved NixOS generation and gateway manifests: stop the host
Caddy, switch back with `<saved-system>/bin/switch-to-configuration switch`,
restore the saved gateway objects, then verify 17480 again. Restore the old
CoreDNS ConfigMap and affected Woodpecker configuration when rolling back
cluster access. These backups must be captured before changing live resources.

NixOS must retain `net.ipv4.conf.all.forwarding=1` for k3s. The k3s module
owns this sysctl: relying on k3s's runtime write alone lets a subsequent
systemd-sysctl reload disable cluster routing. Verify cluster access after a
NixOS switch as well as before it.

The Post Console route is a VPN-only, zero-account read-only framework preview.
Its MCP port 18787 is not proxied. See [Post activation](post-console-preview.md)
for the immutable artifact gate and service-specific handoff.
