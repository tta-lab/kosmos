# Ebook evaluation

BookOrbit runs in the local `ebooks` namespace for a reading evaluation. It is
private: the only client route is the Kepos-published HTTP host on the canonical
loopback gateway.

## Endpoints

- BookOrbit: `http://bookorbit.localhost:17480`

The database has a ClusterIP service only and is not published through Kepos.

## Deploy

Deploy the NixOS generation first. It creates the retained host directories,
adds the local hostname, and installs the Kepos publisher service:

```bash
nh os switch . -H wsl
```

Then add the `bookorbit` service and its ACL to
`kepos/publisher-policy.jsonnet` and run `just kepos-policy-render`; Kepos
hot-reloads that rendered policy without a rebuild or restart.

Then create missing credentials and apply the Tanka environments:

```bash
just ebooks-diff
just ebooks-deploy
just ebooks-status
just kepos-status
```

`just ebooks-deploy` generates random database, JWT, and setup credentials
directly into Kubernetes Secrets when they are absent. Re-running it preserves
the existing credentials. Generated values are never stored in this repository
or printed during deployment.

BookOrbit's first-run page asks for its one-time bootstrap token. Neil can print
that token locally with:

```bash
just bookorbit-bootstrap-token
```

Agents must not run that command or inspect the Secret plaintext.

## Evaluation

Put only a disposable or copied Chinese EPUB into each app. On desktop, phone,
and the Viwoods AiPaper, verify:

1. Login and open the same book.
2. Change font, spacing, theme, and paginated layout.
3. Turn at least twenty pages and check latency and ghosting.
4. Long-press Chinese text, save several highlights, close the reader, and
   reopen each highlight.
5. Suspend and resume the AiPaper.
6. Disconnect and reconnect Kepos, then confirm progress and highlights remain.

Do not import the full library until one candidate passes this evaluation and
its retained state has survived a pod restart.

## Storage

Static PVs use `Retain` and keep temporary evaluation data under:

- `/var/lib/kosmos-k3s/ebooks/bookorbit`
- `/var/lib/kosmos-k3s/ebooks/bookorbit-db`

These directories remain on the WSL virtual disk and are not backups. Removing
the Tanka resources does not remove them automatically.
