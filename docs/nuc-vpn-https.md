# NUC VPN HTTPS

Host Caddy keeps the loopback HTTP/Kepos entry and adds
`https://<id>.nuc.swdl/` on **10.80.12.4:443**. It does not listen on HTTP 80,
LAN addresses or wildcard interfaces. The WSL firewall is masked: protection
comes from the address bind and Caddy's socket-source matcher, not
`allowedTCPPorts`. VPN clients must have sources in `10.80.12.0/24`.
The only internal exception is `10.42.0.0/16` (local k3s Pods), restricted to
`ente-storage.nuc.swdl` for Museum's S3 consumer. Other hosts from that subnet
are rejected. Upstreams remain loopback HTTP; Caddy terminates TLS and
Traefik trusts forwarded HTTPS only from its existing host gateway source.
Unknown HTTPS names never dispatch to an application.

## Authorities and application behavior

Every row retains its existing `<id>.localhost:17480` route and Kepos
publication. The extra `codex-bridge.kepos.internal` alias also remains.
Authentication, data, service identities and credentials are retained.
There is no new ingress token, basic-auth or SSO gate.

| ID / new HTTPS authority prefix | Existing upstream | Public URL / dual-access behavior |
|---|---|---|
| dev-her | 127.0.0.1:3082 | CFL uses browser-relative API/stream/socket URLs; both authorities |
| staging-her | 127.0.0.1:3083 | Same CFL behavior |
| prod-lamplit | 127.0.0.1:3084 | Same CFL behavior; no paid inference needed for ingress checks |
| flickgrove | 127.0.0.1:4318 | **Exception:** supported public Origin changes to HTTPS; old browser/API/WS authority is rejected |
| mihomo-dashboard | 127.0.0.1:9090 | Native API authentication remains; no secret or dashboard reset |
| ente | photos/museum:8080 | **Exception:** both API routes; file operations from either require VPN/CA trust |
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

FlickGrove's `--origin` is `https://flickgrove.nuc.swdl`; loopback MCP stays
`http://127.0.0.1:4318` with native credential checks. On Mac/Pixel, manually
edit the ko Peer URL in browser Settings → Hosts and reuse its existing access
credential. Do not clear storage or recreate the Peer. Old localhost routes
still reach the process but its HTTP API and sockets return 403 for that
unsupported authority. Sessions and state remain in the same directory.

Ente's pinned Museum uses one S3 endpoint per bucket. `are_local_buckets=false`
enables verified TLS; path-style URLs, bucket `b2-eu-cen`, region `garage`,
data and credentials stay unchanged. Museum mounts the existing **public**
company root and uses `SSL_CERT_FILE`; host trust is not inherited by a Pod.
CoreDNS answers **only** `ente-storage.nuc.swdl` with `10.80.12.4` for this
consumer, rather than rewriting it to HTTP-only Traefik. Old Ente API clients
must now also connect VPN and trust the CA to upload/download. Ente endpoint
updates do not create or migrate accounts or stored objects.

## Inputs and certificate provisioning (operator, after review/merge)

The existing public root is `certs/seafarer-root-ca.pem`, SHA256
`DD:CF:E3:80:9F:97:95:B2:A9:E0:FD:CE:B0:E0:7C:61:C4:56:93:9F:C6:31:F5:ED:2A:BB:39:9D:39:CF:E7:4B`.
Already-trusting clients need no second root. New clients must install/trust
this public CA using their platform controls. No CA private key or SW server
private key is transferred. `sfd` deploys supplied material; it is not a
verified signer. There is no production self-signed fallback or automatic renewal.

1. Confirm stable VPN allocation of `10.80.12.4/24` on NUC `tun0`, Mac/iOS
   client-to-client routes and TCP 443 reachability. These are prerequisites,
   not an IP reservation or evidence that connectivity already passed. If the
   address/subnet changes, review the bind, matcher, preflight and cluster DNS
   answer together before deployment.
2. Supply DNS for all 19 `<id>.nuc.swdl` names from the table to `10.80.12.4`.
   Use a wildcard record only if the existing router/DNS supports it; otherwise
   add the exact records. Configure the VPN clients to query that DNS. Test
   resolution on Mac/iOS while VPN is connected. This PR installs no DNS server
   or router/VPN configuration. The internal Museum DNS answer is separate.
3. Generate a NUC-specific key/CSR in a private operator-owned directory:

   ```sh
   umask 077
   issuance="$HOME/.local/share/kosmos/nuc-vpn-issuance"
   mkdir -p "$issuance"
   openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
     -keyout "$issuance/nuc.key" -out "$issuance/nuc.csr" \
     -subj '/CN=*.nuc.swdl' -addext 'subjectAltName=DNS:*.nuc.swdl'
   ```

   Send **only the CSR** to the existing CA operator. Request a server-auth
   leaf with wildcard DNS SAN and its intermediate chain, if any. Receive the
   leaf-first chain as `$issuance/nuc-fullchain.pem`. Signing remains an
   operator action at the existing issuer; no signing command is invented here.
4. Verify the public chain, validity/SAN and key pairing without displaying
   private material:

   ```sh
   openssl verify -purpose sslserver -CAfile certs/seafarer-root-ca.pem \
     -untrusted "$issuance/nuc-fullchain.pem" "$issuance/nuc-fullchain.pem"
   openssl x509 -in "$issuance/nuc-fullchain.pem" -noout -ext subjectAltName
   openssl x509 -in "$issuance/nuc-fullchain.pem" -noout -checkend 86400
   openssl x509 -in "$issuance/nuc-fullchain.pem" -pubkey -noout | \
     openssl pkey -pubin -outform DER | sha256sum
   openssl pkey -in "$issuance/nuc.key" -pubout -outform DER | sha256sum
   ```

   Require matching public-key hashes and `DNS:*.nuc.swdl`. Do not put private
   keys in Git, the Nix store, shell history or logs. Via the existing agenix
   operator workflow ([secrets](secrets.md)), create the two encrypted inputs:

   ```sh
   agenix -e secrets/nuc-vpn-cert.age -i ~/.ssh/agenix_ed25519
   agenix -e secrets/nuc-vpn-key.age -i ~/.ssh/agenix_ed25519
   ```

   The first plaintext is the leaf-first PEM certificate chain; the second is
   the corresponding unencrypted PEM private key. Only the encrypted `.age`
   files may be staged/committed through a reviewed provisioning branch. Both
   are required for declaration. Runtime paths are `/run/agenix/nuc-vpn-cert`
   and `/run/agenix/nuc-vpn-key`, owned by `caddy:caddy`, mode `0400`.

## Ordered activation and acceptance

Do not switch or apply before independent current-head review, merge, signed
inputs and network/DNS preflight. Recheck the registered runtime checkout for
concurrent changes before updating it with `og`; preserve unrelated work.
Save `/run/current-system` and the affected **public** manifests for rollback.
Capture old-route statuses before activation; coordinate the FlickGrove caller
change and Ente VPN prerequisite. Use the existing local-cluster gate.

1. Render/diff gateway and affected applications (`just gateway-diff` and
   corresponding app `*-diff` recipes). Apply the reviewed Ingress objects for
   all 14 cluster IDs; Ingress-only updates need no app restart. Use rendered
   Ingress-only manifests for unaffected workloads, not blanket app deploys.
2. With encrypted inputs present, run `nh os switch . -H wsl` as Neil. Caddy's
   start/reload preflight requires readable material, valid CA chain, wildcard
   SAN, a matching key and `tun0=10.80.12.4/24`. Missing/invalid inputs omit the
   HTTPS fragment and leave loopback HTTP usable. Inspect the journal: HTTP
   success alone is not a passed HTTPS deployment. On boot, if VPN is not yet
   ready, explicitly reload Caddy after it connects. No background VPN mutation
   or polling service is added.
3. Verify runtime readability as consuming user (`sudo -u caddy test -r` each
   path), `systemctl status caddy`, and `ss -ltn`: only loopback 17480 and VPN
   443, no new 80/LAN listener. Reload with `sudo systemctl reload caddy` after
   replacing renewed signed material. Coordinate any narrow FlickGrove restart
   caused by its reviewed unit change; do not interrupt active turns blindly.
4. Apply gateway DNS, Museum's CA/TLS configuration, Grafana Live allowed origins
   and Penpot frontend configuration through their existing Tanka environment
   recipes. Restart/roll out only the affected workloads (Museum's ConfigMap
   subPath update requires a targeted rollout); leave other app data and pods
   alone. Reverify CoreDNS custom-zone loading and Museum DNS/trusted TLS from
   the actual Pod. Do not dump environment variables or signed URL queries.
   For the ordered steps above, the concrete local-cluster commands are:

   ```sh
   # Gate every direct Tanka operation against the existing local API server.
   just _local-k3s
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   for env in photos ebooks cloudreve anki notes feeds codex-bridge observability impri navidrome meilisearch penpot; do
     tk diff "tanka/environments/$env" --target='^Ingress/'
     tk apply "tanka/environments/$env" --target='^Ingress/' --auto-approve=always
   done
   just gateway-apply always
   # Run after certificate/network preflight, in the ordered activation window.
   nh os switch . -H wsl
   just _local-k3s
   tk apply tanka/environments/photos --target='^(ConfigMap/museum|Deployment/museum)$' --auto-approve=always
   tk apply tanka/environments/observability --target='^Deployment/grafana$' --auto-approve=always
   tk apply tanka/environments/penpot --target='^Deployment/penpot-frontend$' --auto-approve=always
   kubectl -n photos rollout status deployment/museum --timeout=120s
   kubectl -n observability rollout status deployment/grafana --timeout=120s
   kubectl -n penpot rollout status deployment/penpot-frontend --timeout=120s
   ```

5. From an actual VPN client, for each ID use trusted TLS (no `-k`):

   ```sh
   curl --noproxy '*' --cacert certs/seafarer-root-ca.pem \
     --resolve grafana.nuc.swdl:443:10.80.12.4 -I https://grafana.nuc.swdl/
   curl --noproxy '*' -H 'Host: grafana.localhost:17480' -I http://127.0.0.1:17480/
   ```

   Run the old-path check on NUC or through the retained Kepos/SSH entry. Use
   `--resolve` only during DNS handoff; separately verify real client DNS.
   Unknown `.nuc.swdl` hosts must not dispatch, non-VPN source addresses must
   fail, and unrelated Pod sources must not reach other HTTPS apps.
6. Browser/API acceptance: verify CFL stream/socket without sending a model
   turn; FlickGrove new-origin identity/socket and existing Peer trees; Grafana
   login/Live; Penpot login, assets, notifications and export on both paths;
   other native app login/API/redirect/link flows on both paths. Use each
   service's baseline (including native 401/403/404); ERPNext's baseline 503
   is an application availability issue. Verify an Ente upload/download on a
   test-owned object with the real client after operator authorization, and
   ensure old clients meet the new VPN prerequisite. Do not log signed URLs.
   Mac/iOS device success, real DNS and actual file operations remain unverified
   until these post-merge checks pass.

Rollback restores the saved NixOS generation and affected public manifests,
including Museum endpoint/TLS/CA and CoreDNS changes, Grafana origins and
Penpot frontend URI. Restore FlickGrove caller URLs in coordination with its
old Origin. Retain the same state/credentials throughout. No automatic reset,
private-key migration or certificate revocation is part of rollback.

Primary contracts: [Caddy bind](https://caddyserver.com/docs/caddyfile/directives/bind),
[TLS](https://caddyserver.com/docs/caddyfile/directives/tls),
[Traefik 3.7 forwarded headers](https://doc.traefik.io/traefik/v3.7/reference/install-configuration/entrypoints/),
[pinned Museum S3 configuration](https://github.com/ente-io/ente/blob/0137a0c754ac0fe4f2c4c7421727c349327eb990/server/pkg/utils/s3config/s3config.go),
[pinned Penpot frontend URI](https://github.com/penpot/penpot/blob/2.18.1/frontend/src/app/config.cljs),
[Miniflux BASE_URL](https://miniflux.app/docs/configuration.html#base-url).
