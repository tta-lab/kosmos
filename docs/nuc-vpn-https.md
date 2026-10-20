# NUC VPN HTTPS

Host Caddy automatically obtains and renews one `*.nuc.guion.io` certificate
using Cloudflare DNS-01, then keeps the loopback HTTP/Kepos entry and adds
`https://<id>.nuc.guion.io/` on **10.80.12.5:443**. It does not listen on HTTP 80,
LAN addresses or wildcard interfaces. The WSL firewall is masked: protection
comes from the address bind and Caddy's socket-source matcher, not
`allowedTCPPorts`. VPN clients must have sources in `10.80.12.0/24`.
The only internal exception is `10.42.0.0/16` (local k3s Pods), restricted to
`ente-storage.nuc.guion.io` for Museum's S3 consumer. Other hosts from that subnet
are rejected. Existing upstreams remain loopback HTTP; Acrylic uses the
explicit LAN HTTP upstream described below. Caddy terminates TLS and
Traefik trusts forwarded HTTPS only from its existing host gateway source.
Unknown HTTPS names never dispatch to an application.

## Authorities and application behavior

Every row in this table has a `<id>.localhost:17480` route. Existing Kepos publications
remain; the Post application has no Kepos publication. The extra
`codex-bridge.kepos.internal` alias also remains.
Authentication, data, service identities and credentials are retained.
There is no new ingress token, basic-auth or SSO gate.

| ID / new HTTPS authority prefix | Existing upstream | Public URL / dual-access behavior |
|---|---|---|
| dev-her | 127.0.0.1:3082 | CFL uses browser-relative API/stream/socket URLs; both authorities |
| staging-her | 127.0.0.1:3083 | Same CFL behavior |
| prod-lamplit | 127.0.0.1:3084 | Same CFL behavior; no paid inference needed for ingress checks |
| lamplit-post | 127.0.0.1:5140 | Native authenticated managed Console; VPN only; [activation](post-console.md) |
| flickgrove | 127.0.0.1:4318 | **Exception:** supported public Origin changes to HTTPS; old browser/API/WS authority is rejected |
| mihomo-dashboard | 127.0.0.1:9090 | Native API authentication remains; no secret or dashboard reset |
| ente | photos/museum:8080 | **Exception:** both API routes; file operations from either require VPN/public TLS trust |
| ente-storage | photos/garage:3900 | Museum now signs HTTPS URLs for this authority; old storage route stays |
| bookorbit | ebooks/bookorbit:3000 | Keep APP_URL/CLIENT_URL; browser API is same-origin; externally generated links retain old URL |
| cloudreve | cloudreve/cloudreve:5212 | Keep stored site settings; native login/API auth remains; verify configured share/storage integrations during deployment |
| anki | anki/anki-sync-server:8080 | Native sync API; configure client endpoint explicitly; `/` need not return 200 |
| memos | notes/memos:5230 | Keep MEMOS_INSTANCE_URL; same-origin browser API; generated instance links retain old URL |
| miniflux | feeds/miniflux:8080 | Keep BASE_URL; browser routes/assets/forms use relative paths; integrations retain old base URL |
| codex-bridge | codex-bridge/codex-bridge:8787 | Native API/token contract retained; `/` need not return 200 |
| erpnext | erpnext/erpnext:8080 | Route only; existing externally managed workload was unavailable (503); do not deploy it to mask ingress status |
| grafana | observability/grafana:3000 | Keep root_url/domain; add both explicit Grafana Live allowed origins; relative browser routes stay usable |
| impri | impri/impri-ui:8080 | Keep BASE_URL/APP_URL; UI's relative `/v1` requests stay on selected authority; generated links retain old URL |
| navidrome | navidrome/navidrome:4533 | Existing relative `/app/` redirect and native auth retained |
| meilisearch | meilisearch/meilisearch:7700 | Native API keys retained; explicitly choose endpoint in callers |
| penpot | penpot/penpot-frontend:8080 | Frontend PUBLIC_URI empty uses supported browser-origin fallback; backend/exporter public URL stays old for generated links |

Old canonical links that an application generates remain old links; they are
not rewritten into VPN URLs. Test any enabled external callback/integration
using its configured authority. This preserves old Kepos use. If an optional
flow cannot use the new authority independently, record the exact flow before
changing its canonical URL or expanding scope. An ingress fixture alone does
not establish application login, upload, export or device acceptance.

FlickGrove's `--origin` is `https://flickgrove.nuc.guion.io`; loopback MCP stays
`http://127.0.0.1:4318` with native credential checks. On Mac, manually
edit the ko Peer URL in browser Settings → Hosts and reuse its existing access
credential. Do not clear storage or recreate the Peer. Old localhost routes
still reach the process but its HTTP API and sockets return 403 for that
unsupported authority. Sessions and state remain in the same directory.

Ente's pinned Museum uses one S3 endpoint per bucket. `are_local_buckets=false`
enables verified TLS; path-style URLs, bucket `b2-eu-cen`, region `garage`,
data and credentials stay unchanged. Museum uses its pinned image's default public CA bundle; there is no company-root-only
`SSL_CERT_FILE` override or CA mount.
CoreDNS answers **only** `ente-storage.nuc.guion.io` with `10.80.12.5` for this
consumer, rather than rewriting it to HTTP-only Traefik. Old Ente API clients
must now also connect VPN and use verified public TLS to upload/download. Ente endpoint
updates do not create or migrate accounts or stored objects.

## DNS-01 inputs and network preflight

No manual leaf, key or CA installation is needed. Host Caddy 2.10.0 uses the
pinned Cloudflare provider 0.2.4 through Nix's `caddy.withPlugins`. Its
invalid-token-format diagnostic is patched to omit the supplied credential.
The existing raw-token encrypted input is `secrets/cloudflare-ddns-token.age`;
agenix supplies `/run/agenix/cloudflare-ddns-token`, `caddy:caddy`, mode `0400`.
The Caddyfile contains only a runtime file placeholder. September's DDNS/DNS-01
history declared Zone Read + DNS Edit scoped to `guion.io`; current validity
and permissions remain unverified. Do not manually decrypt/read/print the token.
Do not reuse the unrelated Cloudflare Tunnel credential.

Only public TXT validation at `_acme-challenge.nuc.guion.io` is required.
Caddy uses Let's Encrypt, DNS-01 only, a two-minute ACME operation timeout and
two-minute propagation timeout, with public resolvers `1.1.1.1:53` and
`8.8.8.8:53` to avoid internal DNS shadowing. No public A/AAAA record, inbound
public 80/443, proxy, DDNS revival or router port-forward is needed. Caddy
retries failed issuance with backoff; timeout bounds individual operations,
not total renewal lifetime. Authentication/network failure leaves old HTTP
available and does not substitute an insecure/self-signed certificate. The
persistent Caddy data directory `/var/lib/caddy` retains account/certificate
state under its existing user and native private directory permissions; do
not inspect private keys, erase this directory or force repeated issuance.

The current assigned NUC address is `tun0=10.80.12.5/24`; a server reservation
has not been established. Confirm that exact address and Mac's VPN route before
activation. Another VPN allocation requires a coordinated DNS/configuration
change; this fixed listener does not guarantee reachability after reallocation. The Ruijie OpenVPN/DNS server is `192.168.6.1`.
Its previous `nuc.swdl` records do not supply the new names. The original
rollout required **19 exact**
`<id>.nuc.guion.io` A records to `10.80.12.5`, or a wildcard
only if the router explicitly supports it. Preserve other records. Check each
with `dig @192.168.6.1 NAME A +time=2 +tries=1`; UDP currently works but TCP53
was refused during the earlier audit. Do not assume recursive DNS works.

The operator updated router DNS to `.5` on 2026-10-20. Fresh Mac OS resolution
and trusted HTTPS passed for Acrylic and FlickGrove. Check each remaining
authority before deployment; this evidence does not establish every record
or a server-side address reservation. No new record is needed for Post.

On Mac, inspect `/etc/resolver/nuc.guion.io` and any symlink before creation;
preserve meaningful existing contents. If absent, the operator creates a
root-owned mode `0644` file with exactly `nameserver 192.168.6.1` plus newline.
Do not overwrite/delete the operator-owned `/etc/resolver/nuc.swdl` or alter
global DNS, `/etc/resolv.conf`, VPN profiles or Mihomo. `scutil --dns` must show
the new matching-domain resolver; `dscacheutil -q host -a name NAME` must return
`10.80.12.5` for all 20 existing names. Acrylic adds one exact record as described
below. Default `dig` does not exercise macOS's matching-domain
resolver. iOS is deferred. Museum's explicit internal storage DNS is separate.

## Acrylic on N5 Pro: additional VPN-only authority

Spec #4287 adds only `https://acrylic.nuc.guion.io` → **HTTP
192.168.1.88:8787** on the same Caddy VPN listener. `/erp/`, deep links,
assets, `/api` and uploads pass through without path stripping or rewriting.
Caddy preserves the external Host and supplies `X-Forwarded-Host` and
`X-Forwarded-Proto: https`. Native application authentication remains the
application's responsibility; there is no ingress login or timeout/body-limit
override. Background Sparrow jobs do not require an indefinitely open request.

This authority has no localhost HTTP route, Kepos publication or k3s workload.
The 20 existing HTTPS authorities, HTTP aliases and exact storage Pod exception
remain. Acrylic is available only to actual socket sources in `10.80.12.0/24`;
forwarded client headers cannot grant access. A storage Pod source is also
denied for Acrylic. Unknown names from VPN sources return 421; non-VPN sources
return 403 before dispatch. No second VPN, Caddy, certificate or public listener
is needed on N5 Pro. The LAN hop carries plaintext HTTP: N5 Pro's application
port must be reachable only from the required KO source(s).

This PR supplies configuration, documentation and isolated validation only.
After review and merge, Orc coordinates these operator steps with Acrylic
spec #4286, which owns the self-hosted API/ERP artifact, application service,
native auth, data and Sparrow/jobs version readiness. Existing cloud domains
`acrylic-api.guion.io` and `acryerp.guion.io` stay unchanged. Do not claim
cross-host business acceptance until those dependencies are deployed.

1. Resolve the current aliases before connecting:

   ```sh
   ssh -G nuc | awk '$1 == "hostname" || $1 == "user" || $1 == "port"'
   ssh -G n5pro | awk '$1 == "hostname" || $1 == "user" || $1 == "port"'
   ssh nuc 'ip route get 192.168.1.88'
   ```

   The current LAN endpoints are NUC `192.168.1.125/neil` and N5 Pro
   `192.168.1.88/root`; SSH configuration at execution time is authoritative.
   WSL's route `src` may be translated by Windows NAT. Confirm the actual
   incoming source on N5 Pro with a coordinated metadata-only connection probe
   (for example `nc -vz -w 3 192.168.1.88 8787` from NUC and `ss -tn sport =
   :8787` on N5 Pro, or a filtered SYN-only packet metadata capture).
   A short probe may require a held connection to observe it with `ss`.
   The operator restricts N5 Pro TCP 8787 to the observed necessary KO source(s)
   before exposing the service. **10.80.12.5 is the VPN listener address, not
   evidence of the LAN connection's source.** No firewall changes run in this PR.
2. Confirm #4286's artifact/service is ready on the fixed LAN endpoint with
   external origin `https://acrylic.nuc.guion.io`. Check reachability and native
   health without dumping credentials, environment files or private responses.
   Keep existing wildcard certificate storage and DNS-01 settings. Apply the
   reviewed KO system generation only in the coordinated activation window.
   The real deployment checkout is on `ssh nuc` at
   `/home/neil/code/projects/tta-lab/kosmos`, not the Mac checkout or an isolated
   `/tmp` validation snapshot. As **neil**, verify the repository and clean main,
   update through `og`, then require the exact reviewed merged main HEAD before
   following the existing switch procedure. Substitute that merged commit below
   (a squash merge may differ from the PR head); stop if any check fails:

   ```sh
   ssh -t nuc bash
   set -eu
   cd /home/neil/code/projects/tta-lab/kosmos
   test "$(id -un)" = neil
   test "$(git rev-parse --show-toplevel)" = /home/neil/code/projects/tta-lab/kosmos
   test "$(git branch --show-current)" = main
   test -z "$(git status --porcelain)"
   git rev-parse HEAD
   og pull
   test -z "$(git status --porcelain)"
   kosmos_merged_head=REPLACE_WITH_REVIEWED_MERGED_MAIN_SHA
   test "$(git rev-parse HEAD)" = "$kosmos_merged_head"
   nh os switch . -H wsl
   ```

   These are later operator actions; implementation does not update or activate
   that checkout. Run `nh` as neil, allowing it to elevate only activation.
   The earlier full migration steps are not a prerequisite to redeploying
   unrelated applications for this single route.
3. Verify the existing internal DNS A record `acrylic.nuc.guion.io → 10.80.12.5`
   at the existing VPN DNS server. Preserve the existing 20 records (including Post) and the existing
   macOS resolver file; no public A/AAAA or Cloudflare domain change is needed.

   ```sh
   dig @192.168.6.1 acrylic.nuc.guion.io A +time=2 +tries=1
   dscacheutil -q host -a name acrylic.nuc.guion.io
   ```

   DNS-01 proves domain ownership, not VPN reachability. iOS/mobile VPN DNS
   and acceptance remain unverified.
4. Verify the listener and trusted TLS from a VPN client without `-k`:

   ```sh
   curl --noproxy '*' --connect-timeout 3 --max-time 10 \
     --resolve acrylic.nuc.guion.io:443:10.80.12.5 -I https://acrylic.nuc.guion.io/erp/
   curl --noproxy '*' --connect-timeout 3 --max-time 10 -I https://acrylic.nuc.guion.io/erp/
   ```

   Verify ERP deep-link refresh, emitted asset URLs, same-origin API calls,
   unauthenticated private-API rejection and an authorized test-owned upload.
   Verify path/query/body, Host and forwarded HTTPS using application-owned
   diagnostics that do not log credentials. An isolated proxy fixture does not
   prove real app login, uploads or job completion. From VPN, an unknown
   wildcard host must return 421; from an existing authorized non-VPN test
   source, Acrylic must never dispatch (403 if the listener is reachable).
   Recheck existing HTTP/HTTPS routes and the storage-only Pod exception.
5. For failure isolation, distinguish DNS failure, VPN routing/TLS failure,
   Caddy's source 403, unknown-host 421, native auth rejection and upstream
   connection failure (normally 502). Inspect only sanitized status metadata;
   do not stop the real application just to induce a failure. Check the LAN
   route and N5 Pro service/ACL when Caddy cannot connect.

Before activation, save the current system generation and this record's prior
DNS state. Rollback restores the saved KO generation and only this DNS record's
prior state if it was changed by this rollout. Keep other DNS/resolver entries,
wildcard certificate storage, app data and credentials. Application rollback
and migration remain owned by #4286. No activation, DNS/firewall write,
certificate request or application install is part of implementation checks.

## Current-address persistence handoff (.5)

This source-only address correction does not activate services. The live
Caddy-only recovery uses `/run/nuc-vpn-https-recovery/https-template` and
`/run/nuc-vpn-https-recovery/prepare-vpn-https`, selected by
`/run/systemd/system/caddy.service.d/zz-vpn-current-address.conf`.
Its backup and rollback script are retained at
`/var/tmp/nuc-vpn-https-recovery-20261020`. Do not remove these during source
validation; a runtime drop-in can silently shadow the new generated unit.

After independent review and merge, Orc coordinates a separate maintenance
window (including active FlickGrove turns):

1. Resolve `ssh -G nuc`; use neil's real checkout
   `/home/neil/code/projects/tta-lab/kosmos`. Require clean main, update with
   `og pull`, and match the exact reviewed merged SHA as in the checkout gate
   above. Confirm fresh `ip -4 -o address show dev tun0` has `.5/24` and each
   authority's router/OS DNS returns `.5`. Stop on mismatch; do not reconnect
   VPN, add an address alias or alter the VPN server as part of this handoff.
2. Save the current generation, effective public Caddy unit and CoreDNS
   ConfigMap outside Git. Retain the known recovery backup. Build/inspect the
   merged closure and activation impact first. Do not read credentials or
   certificate keys, and preserve Caddy's persistent ACME data.
3. Immediately before the native switch, remove **only** the known runtime
   drop-in, then daemon-reload, without an intervening Caddy reload/restart:

   ```sh
   sudo rm /run/systemd/system/caddy.service.d/zz-vpn-current-address.conf
   sudo systemctl daemon-reload
   nh os switch . -H wsl
   ```

   Run `nh` as neil from the real merged checkout. Confirm effective
   ExecStartPre/ExecReload now select the merged Nix-store preparer/template,
   not `/run/nuc-vpn-https-recovery`, and listeners are only
   `127.0.0.1:17480` and `10.80.12.5:443`. Verify normal hostname trusted HTTPS
   and loopback HTTP. Only after successful acceptance remove the known
   `/run/nuc-vpn-https-recovery/{https-template,prepare-vpn-https,candidate.caddyfile}`
   files; retain the backup. Do not delete `/run/caddy/vpn/https.caddy`, which
   remains the managed preparer's runtime output. If switch fails, preserve
   recovery files and restore the saved drop-in from the known backup before
   daemon-reload/native reload; verify `.5` TLS again. The backup's original
   `rollback.sh` instead restores the old `.4` source and loopback-only state
   while tun0 is `.5`; it is not a rollback to working `.5` HTTPS.
4. A NixOS generation switch does **not** apply Tanka/CoreDNS. Separately
   render/diff and apply only the reviewed storage DNS ConfigMap through the
   existing local-cluster gate:

   ```sh
   just _local-k3s
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   tk diff tanka/environments/devops --target='configmap/coredns-custom'
   tk apply tanka/environments/devops --target='configmap/coredns-custom' --auto-approve=always
   ```

   Verify actual Museum Pod DNS returns `.5` and trusted storage TLS; this
   correction needs no new Ingresses or blanket application rollout. Preserve
   all other CoreDNS rewrites. On failure, restore only the saved ConfigMap
   through the same owner and verify its consumer; coordinate system rollback
   separately, retaining the working recovery artifacts and backup.

The following section records the broader original ingress migration. It is
not a checklist to rerun for this address-only correction.

## Ordered activation after current-head review and merge

No live activation or Cloudflare challenge is part of isolated implementation
checks. Orc coordinates active turns, inputs and this postmerge handoff.
Recheck runtime cleanliness/HEAD before `og pull`; preserve concurrent edits.
Save `/run/current-system` and affected public manifests outside Git for rollback.
Record old route/native API baselines, including ERPNext's prior 503.

1. Confirm the provider is built (`caddy list-modules` includes
   `dns.providers.cloudflare`), credential declaration metadata and outbound
   ACME/Cloudflare/public DNS access. Runtime readability can be checked after
   switch with `sudo -u caddy test -r /run/agenix/cloudflare-ddns-token`;
   never print the file. Coordinate FlickGrove's unit change with active turns.
2. Render/diff the local-cluster gateway and affected environments. Apply only
   the 14 Ingress objects, then the reviewed CoreDNS custom storage zone. Keep
   the old localhost rules and Kepos publications. Direct Tanka operations
   must pass the existing local-k3s gate:

   ```sh
   just _local-k3s
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   for env in devops photos ebooks cloudreve anki notes feeds codex-bridge observability impri navidrome meilisearch penpot; do
     tk diff "tanka/environments/$env" --target='ingress/.*'
     tk apply "tanka/environments/$env" --target='ingress/.*' --auto-approve=always
   done
   tk diff tanka/environments/devops --target='configmap/coredns-custom'
   tk apply tanka/environments/devops --target='configmap/coredns-custom' --auto-approve=always
   ```

3. Run `nh os switch . -H wsl` as Neil in the coordinated window. Prep runs
   before native start and after the ExecReload reset, before native Caddyfile
   reload. Missing declaration/readability, invalid format or absent VPN
   address omits HTTPS and keeps HTTP; sanitized journal outcomes explain why.
   If VPN was absent at boot, explicitly reload only Caddy after it connects.
   Check service/listener metadata: only `127.0.0.1:17480` and `10.80.12.5:443`,
   no port80/LAN listener. Issuance is asynchronous; HTTP success alone is not
   HTTPS readiness. Report bounded sanitized issuance errors/status; never
   dump an environment, API headers, admin config exports or raw token logs.
4. After trusted wildcard TLS is ready, apply the reviewed Museum, Grafana
   and Penpot pod changes; no blanket app deployment. Museum mounts its config
   with subPath. Its Pod template is unchanged from the running `cae83` baseline
   (PR80 was never activated), so explicitly restart only Museum after applying
   its ConfigMap to load the new endpoint/TLS settings:

   ```sh
   just _local-k3s
   tk apply tanka/environments/photos --target='(configmap/museum|deployment/museum)' --auto-approve=always
   kubectl -n photos rollout restart deployment/museum
   tk apply tanka/environments/observability --target='deployment/grafana' --auto-approve=always
   tk apply tanka/environments/penpot --target='deployment/penpot-frontend' --auto-approve=always
   kubectl -n photos rollout status deployment/museum --timeout=120s
   kubectl -n observability rollout status deployment/grafana --timeout=120s
   kubectl -n penpot rollout status deployment/penpot-frontend --timeout=120s
   ```

   Verify actual Museum Pod DNS and public TLS trust, not host inheritance.
   Keep its bucket, region, path-style, credentials and data unchanged.
5. From Mac, test trusted TLS without `-k` or a company CA override:

   ```sh
   curl --noproxy '*' --connect-timeout 3 --max-time 10 \
     --resolve grafana.nuc.guion.io:443:10.80.12.5 -I https://grafana.nuc.guion.io/
   curl --noproxy '*' -I https://grafana.nuc.guion.io/
   curl --noproxy '*' -I http://grafana.localhost:17480/
   ```

   `--resolve` isolates VPN/TLS during DNS handoff; real OS DNS must separately
   pass for all19 before claiming Mac ready. Capture public SAN/issuer/chain/
   expiry from the network certificate, and persistent renewal configuration
   metadata; do not inspect Caddy's private keys or force renewal to repeat proof.
6. Check every route's old/new native API/auth/redirect/link baseline, not just
   alias homepages. Verify CFL API/SSE/socket without a model turn; FlickGrove
   identity/socket and manually updated Mac Peer URL with credential reuse;
   Grafana Live; Penpot login/assets/notifications/export on both paths. Keep
   native app auth. Unknown names never dispatch, outside VPN sources fail,
   and the Pod exception permits only storage. Old FlickGrove browser/API/WS
   Origin rejects after activation; old Ente API callers also need VPN for
   signed file URLs. An Ente test-owned object upload/download requires an
   authorized existing client; otherwise report that precise gap. ERPNext
   availability is separate from ingress. Mobile/iOS remains unverified.

Rollback restores the saved NixOS generation and affected public manifests,
including Museum's original endpoint/trust and CoreDNS, Grafana origins and
Penpot frontend configuration; coordinate FlickGrove's old Origin/caller URL.
In the coordinated rollback window, after restoring the saved Museum
ConfigMap/Deployment, restart only Museum so its subPath-mounted config reloads:

```sh
kubectl -n photos rollout restart deployment/museum
kubectl -n photos rollout status deployment/museum --timeout=120s
```

Verify the restored storage endpoint and upload/download behavior through the
restored access path before declaring rollback complete.
Retain all app identity/state/credentials and Caddy's ACME storage. DNS cleanup
is a separate exact operator action: remove only records/resolver file created
for this rollout after confirming ownership, never other resolver files or
parent directories. No credential revocation/migration or automatic cleanup.

Primary contracts: [Caddy TLS/ACME](https://caddyserver.com/docs/caddyfile/directives/tls),
[DNS challenge](https://caddyserver.com/docs/automatic-https#dns-challenge),
[Cloudflare provider](https://github.com/caddy-dns/cloudflare/tree/v0.2.4),
[Let's Encrypt DNS-01](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge),
[pinned Museum S3 configuration](https://github.com/ente-io/ente/blob/0137a0c754ac0fe4f2c4c7421727c349327eb990/server/pkg/utils/s3config/s3config.go).
