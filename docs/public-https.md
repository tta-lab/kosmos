# Public IPv6 HTTPS

`https://ddns-smoke.guion.io:27443/` serves the DDNS smoke page through the
local k3s canonical Caddy gateway. Cloudflare hosts DNS with proxying disabled.
Clients need IPv6 connectivity, either directly or through their proxy.

The WSL `public-https.socket` listens on IPv6 TCP 27443. Its socket-activated
service forwards TLS unchanged to `127.0.0.1:18443`, the gateway Pod's host port.
Caddy terminates TLS and obtains and renews its certificate using Cloudflare
DNS-01. Certificate issuance needs no inbound port 80 or 443. HTTP/3 is disabled
because the public listener forwards TCP only. Internal HTTP routes continue
using `127.0.0.1:17480`.

## Automatic DNS updates

The host's `ddns-go.service` checks the address every 300 seconds. It runs without
a web UI and publishes only the AAAA record for `ddns-smoke.guion.io`, with
`proxied=false` and a 300-second TTL. Configuration is generated at startup from
a systemd credential; edit the repository's renderer to change the domain.

`scripts/select-ddns-ipv6` selects the preferred global IPv6 on `eth1` whose
interface identifier is `::8`, the DHCPv6 service address observed on this host.
The ISP prefix is not fixed. Deprecated, temporary, tentative, failed and expired
addresses are rejected. This explicit identifier also excludes Windows privacy
addresses that WSL does not mark temporary. If no unique address matches, the
command fails and ddns-go leaves the existing DNS record in place. If DHCPv6
changes the service identifier or WSL changes its interface name, update the
selector after verifying the replacement address.

## Credentials and installation

The Cloudflare token needs Zone Read and DNS Edit permissions scoped to
`guion.io`. The same token supports DDNS and Caddy's DNS-01 TXT records.
An operator stores it with `agenix -e secrets/cloudflare-ddns-token.age`;
never commit plaintext. NixOS decrypts it to a root-only agenix file.
`caddy-secret-sync.service` copies it into the local cluster's
`devops/caddy-cloudflare` Secret and restarts an existing gateway when the Secret
version changes. DDNS reads it through systemd's credential directory.

Build and import the custom Caddy image before applying the gateway. The image
pins Caddy 2.10.0 and `caddy-dns/cloudflare` 0.2.4, which supports current
Cloudflare token formats. The local deployment uses `imagePullPolicy: Never`.

```bash
just caddy-image-load
nh os switch . -H wsl
just public-https-diff
just public-https-deploy
```

The deploy recipe builds/imports the image, synchronizes the Secret, applies
only the gateway ConfigMap, Deployment and certificate PVC, then waits for the
rollout. The `canonical-gateway-data` PVC preserves ACME account and certificate
state; do not delete it when updating the image.

For networks that cannot reach the default Go checksum endpoint, the image
builder accepts `GOPROXY` and `GOSUMDB`. A checksum mirror can retain the official
verification identity, for example
`GOSUMDB='sum.golang.org https://goproxy.cn/sumdb/sum.golang.org'`.

On Windows, run `scripts/enable-public-https.ps1` in an elevated PowerShell 7
session to permit inbound TCP 27443 through the WSL Hyper-V firewall. Upstream
router/firewall rules must also permit the connection.

## Verification

```bash
systemctl status ddns-go caddy-secret-sync public-https.socket
journalctl -u ddns-go --since '10 minutes ago'
just public-https-diff
curl --noproxy '*' --connect-timeout 10 https://ddns-smoke.guion.io:27443/
```

Verify from a separate IPv6-capable network as well. A local success alone does
not establish public reachability. Use `curl --resolve` with the current service
IPv6 when separating DNS cache problems from transport failures. Failed probes
from individual networks do not establish that the service is unreachable from
all networks.
