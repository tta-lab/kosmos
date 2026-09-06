# Anki Sync

Anki's official Rust sync server binary runs in the local single-node k3s
cluster, packaged in the pinned third-party `jeankhawand/anki-sync-server`
image. It is available only through the private Kepos `anki` service; there is
no public domain, web UI, registration flow, or direct NodePort.

## Endpoint and account

Kepos subscribers use `http://anki.localhost:17480/` as the self-hosted sync
server URL. Current Anki Desktop, AnkiMobile, and AnkiDroid clients use this
single base URL for collection and media sync. Do not add `/sync/` or
`/msync/` unless an old client explicitly requires separate endpoints.

The initial account is `ooneil`. The server has no administrator or signup
screen: credentials are declared when the service starts and entered in the
client's AnkiWeb account fields.

## Secret

Agents must not read or decrypt the Anki credential. The initial random
password is already encrypted in `secrets/anki-sync-env.age`. To view it in
your own terminal for entry into an Anki client:

```bash
agenix -d secrets/anki-sync-env.age
```

To replace the password, edit the encrypted file interactively:

```bash
agenix -e secrets/anki-sync-env.age
```

Enter exactly one env-file line, replacing the placeholder with a password:

```text
SYNC_USER1=ooneil:<password>
```

After a NixOS rebuild, the root-owned `anki-secret-sync.service` validates the
account name and applies Kubernetes Secret `anki/anki-sync-env` only to the
guarded local cluster. Restarting the service updates the Secret and rolls the
Anki deployment when it already exists.

## Deploy

NixOS owns the retained host directory, agenix Secret sync, loopback host, and
Kepos publisher service. Tanka owns the Kubernetes resources. Deploy in this
order:

```bash
nh os switch . -H wsl
sudo systemctl restart anki-secret-sync.service
sudo systemctl status anki-secret-sync.service --no-pager
just anki-diff
just anki-deploy
just anki-status
just kepos-status
```

The deployment uses the pinned Anki 26.05 image digest, one replica, and a
retained 10 GiB static volume at `/var/lib/kosmos-k3s/anki`. The canonical
Caddy gateway supplies the 512 KiB HTTP read buffer required by Anki media
downloads.

## First sync

1. Confirm which device has the complete and newest collection.
2. Connect Kepos to the kosmos publisher. The current Kepos client does not
   show a separate `anki` service tile; the hostname route becomes available
   when the publisher is connected.
3. Set the client's self-hosted sync server to
   `http://anki.localhost:17480/`.
4. Enter username `ooneil` and the password stored in agenix.
5. On the complete device, choose **Upload** when Anki reports that the server
   is empty.
6. On each other device, choose **Download** for its first sync.
7. Add a disposable note with media, sync both ways, restart the deployment,
   and verify the note and media again.

Do not initialize different collections independently on multiple devices.
The first upload/download choice replaces one side and can discard data.

## Operations

```bash
just anki-status
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl -n anki logs deployment/anki-sync-server
curl --fail http://anki.localhost:17480/health
```

The retained directory is on the WSL virtual disk and is not an off-host
backup. Stop the deployment before copying or restoring it. Before upgrading
Anki clients across a protocol-changing release, update and verify the pinned
server image first.
