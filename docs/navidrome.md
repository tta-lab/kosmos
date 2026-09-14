# Navidrome

Navidrome serves Neil's local music library from the local k3s cluster. It is
available privately through Kepos, not through the public Cloudflare Tunnel.

The Tanka environment is `tanka/environments/navidrome`.

Current settings:

- Music library: `/mnt/kosmos-cloudreve/navidrome/music`
- Database and caches: `/mnt/kosmos-cloudreve/navidrome/{data,cache}`
- Image: `deluan/navidrome:0.64.0` pinned by digest
- Internal Service: `navidrome.navidrome.svc.cluster.local:4533`
- Private endpoint: `http://navidrome.localhost:17480`
- Public route: none
- Downloads: disabled
- Public shares: disabled
- Replica count: one (`Recreate` strategy, preserving a single SQLite writer)

The Micron storage service verifies the filesystem UUID before creating the
three static PV directories. The Deployment's init container then waits for the
disk-resident `.kosmos-storage-ready` marker before Navidrome can start. It
mounts data and cache read-write and `/music` read-only, all as Neil's UID/GID.
This guards startup only; it is not an off-host backup or a runtime disk-loss
fence.

## Deploy and check

```bash
nh os switch . -H wsl
just navidrome-diff
just navidrome-deploy
just navidrome-status
curl --fail --header 'Host: navidrome.localhost' http://127.0.0.1:17480
```

The NixOS switch removes the former systemd Navidrome instance. Deploy the
Kubernetes workload only after that switch, so SQLite has one writer. The
existing database keeps `/music` as its internal library path; do not change
that mount path.

On a first deployment, create the admin user in the browser:

```text
http://navidrome.localhost:17480
```

Add any local client accounts from the Navidrome admin UI. Remote access is not
publicly configured; approved Kepos subscribers use the same private endpoint.
