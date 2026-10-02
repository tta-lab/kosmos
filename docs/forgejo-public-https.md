# Forgejo public HTTPS

Forgejo's canonical origin is `https://git.guion.io:27443/`. Cloudflare serves
DNS only; clients need IPv6 directly or through their proxy. Caddy terminates
TLS with its existing DNS-01 credentials and persistent certificate volume.
Forgejo continues to serve HTTP on its private Kubernetes Service, port 3000.

CoreDNS resolves `git.guion.io` to the canonical gateway Service inside the
cluster, preserving the query name in the answer. Service port 27443 reaches
Caddy port 18443. On WSL the same hostname resolves to `::1` and reaches the
existing IPv6 listener. Host, server, build-step and Dagger proxy bypasses
include the new hostname. Neither CI nor local registry clients need the
household's public IPv6 loopback path.

Woodpecker's UI stays private. Its Forgejo API and webhooks still use cluster
Services; its Forgejo OAuth origin changes to the new HTTPS origin. Its own
callback URL stays unchanged. Forgejo's old HTTP user endpoint and Kepos
service are removed. Existing checkout remotes and registry credentials do
not change automatically.

## Coordinated cutover

This is an operator-run transition on the local WSL cluster, using
`/etc/rancher/k3s/k3s.yaml` and `https://127.0.0.1:26443`. Allow a brief
maintenance window. Do not target the remote Guion cluster.

Prepare all registry consumer PRs and their runtime changes before starting.
This cutover removes the former HTTP entry immediately: existing Pods may keep
running, but their old-authority image pulls and Git operations will fail.
Confirm remote deployment approval and a coordinated maintenance window before
cutting over; PR preparation alone does not make those nodes ready. Verify IPv6
reachability on both Guion workers and the Seafarer target, migrate mirror and
credential authority keys, and schedule any required node restarts explicitly.

1. Review the selected manifests with `just show` and
   `just forgejo-public-diff`. Confirm the recent Forgejo source-recovery backup
   succeeded; it excludes Packages and is not a full-instance restore. Record
   the previous non-secret workload configuration and DNS records for rollback.
2. Take over **only** `git.guion.io` in Cloudflare DNS: remove conflicting old
   A/CNAME/AAAA records and leave one DNS-only AAAA pointing to the address from
   `ip -j -6 address show dev eth1 | scripts/select-ddns-ipv6`. Use TTL 300.
   DDNS maintains this AAAA afterward; it does not clean up old A/CNAME records.
   DNS does not distinguish ports, so this replaces the former hostname target.
3. Activate the checked NixOS configuration with `nh os switch . -H wsl` as
   Neil. This updates hosts, proxy bypasses, DDNS and removes the old HTTP
   registry mirror. No secret plaintext needs to be displayed.
4. Run a fresh `just forgejo-public-diff`, then
   `just forgejo-public-deploy`. This targets only the gateway, custom CoreDNS,
   Forgejo, Woodpecker, Dagger and the existing certificate PVC. It does not
   apply unrelated applications or delete storage.
5. Verify TLS and health locally and from an independent IPv6-capable network:

   ```bash
   curl --noproxy '*' --fail https://git.guion.io:27443/api/healthz
   curl --noproxy '*' --resolve 'git.guion.io:27443:[::1]' \
     --fail https://git.guion.io:27443/api/healthz
   curl --noproxy '*' --silent --dump-header - --output /dev/null \
     https://git.guion.io:27443/v2/
   ```

   The registry should return 401 with a Bearer realm under the new HTTPS
   origin. Verify in-cluster A and AAAA responses, HTTPS from a Woodpecker
   build Pod and a Dagger execution container, and OAuth login. A successful
   page request alone does not prove these paths work.
   After login, verify the session cookie has `Secure`, API `html_url` and
   `clone_url` use the new origin, and redirects to Forgejo use that origin.
6. Refresh Woodpecker's active repositories through its supported Repair API:
   `POST /api/repos/repair` with a Woodpecker administrator's login/token.
   Woodpecker 3.18 refreshes clone URLs and repairs the internal webhook.
   Verify all seven active repositories use the new clone URL. Normal incoming
   Forgejo webhooks also update repository metadata before scheduling a build.
   Do not directly update the Woodpecker database.
7. Verify one controlled Git push/CI run and LFS transfer using a dedicated
   acceptance repository. Verify OCI push/pull with a dedicated artifact and
   the actual Dagger and k3s consumer paths. Use existing authorized credentials
   without displaying them; the agent must not inspect plaintext secrets.
8. Render the reviewed Kepos source with `just kepos-policy-render` to withdraw
   the old Forgejo service. Preserve other pending policy changes when preparing
   this source; do not overwrite unrelated live ACL work.
9. Confirm the existing smoke HTML endpoint, Woodpecker and a representative
   private gateway-routed application remain healthy. Run
   `just forgejo-public-diff` and confirm no outstanding deployment drift.

## Client handoff

After public HTTPS passes, update each checkout's origin to
`https://git.guion.io:27443/OWNER/REPO.git` and its registered Organon remote
using the supported project workflow. The Kosmos checkout and its Kepos Nix
input use the new origin too; the pinned Kepos source revision is unchanged.

Registry references become `git.guion.io:27443/guionai/IMAGE:TAG` or a digest.
Log in against `git.guion.io:27443` and register pull/push credentials under
that authority. Check Woodpecker registry entries, Dagger publisher configuration,
external deployment consumers and imagePullSecrets before their next run.
Changing the origin does not move or republish existing images.

The active Woodpecker repositories at planning time were
`GuionAI/document-service`, `GuionAI/flick-backend`,
`GuionAI/flicknote-services`, `GuionAI/sliqs-services`, `GuionAI/seafarer`,
`GuionAI/guion-devops` and `LamplitIsles/lamplit`. Review their workflow and
publisher references; independent repository code changes belong to their own
PRs. The seven prepared consumer migrations also include `GuionAI/sf-deploy`,
which owns Seafarer pull credentials and node configuration. Before remote
apply, re-register the existing `forgejo-packages` Secret credentials under
`git.guion.io:27443` in `apps-dev`, `apps-prod` and `sliqs-dev`; wait for Zot
credentials synchronization and restart Zot to load its new key. Guion worker
mirror entries map the new authority to the existing local Zot endpoint.
Seafarer uses direct public HTTPS and a regenerated `regcred`. Preserve image
tags/digests and unrelated node configuration. No local k3s workload image
referenced the old authority at inventory time.

## Access verification and rollback

Repository publication decisions and visibility changes are owned by Neil,
separate from configuration. New repositories default to private. Check
anonymous and ordinary non-member access to protected GuionAI repositories
and Packages. Instance administrators remain able to read private content.
Wiki, issues and releases are outside this cutover's audit scope.

If Git/CI/OCI validation fails, restore the previous configuration, activate
the previous NixOS generation and restore the recorded DNS and Kepos policy.
Keep Forgejo and Caddy storage intact. This transition changes addresses and
configuration, not data format; it requires no database-content rollback.

References: [Forgejo v15 configuration](https://forgejo.org/docs/v15.0/admin/config-cheat-sheet/),
[Woodpecker Forgejo integration](https://woodpecker-ci.org/docs/administration/configuration/forges/forgejo),
[Woodpecker 3.18 Repair API](https://github.com/woodpecker-ci/woodpecker/blob/v3.18.0/server/api/repo.go).
