# Ebook evaluation

BookLore and BookOrbit run side by side in the local `ebooks` namespace for a
short reading evaluation. Both are private: the only client routes are the
Kepos-published HTTP hosts on the canonical loopback gateway.

## Endpoints

- BookLore: `http://booklore.localhost:17480`
- BookOrbit: `http://bookorbit.localhost:17480`

The databases have ClusterIP services only and are not published through
Kepos. BookLore and BookOrbit use independent credentials, databases, and
storage so either evaluation can be removed without changing the other.

## Deploy

Deploy the NixOS generation first. It creates the retained host directories,
adds the local hostnames, and publishes both Kepos service IDs:

```bash
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
sudo env NIX_CONFIG="$(cat ~/.config/nix/nix.conf)" \
  nixos-rebuild switch --flake .#wsl
```

Then create missing credentials and apply both Tanka environments:

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

BookLore creates its administrator through the first-run web page. BookOrbit's
first-run page asks for its one-time bootstrap token. Neil can print that token
locally with:

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

- `/var/lib/kosmos-k3s/ebooks/booklore`
- `/var/lib/kosmos-k3s/ebooks/booklore-db`
- `/var/lib/kosmos-k3s/ebooks/bookorbit`
- `/var/lib/kosmos-k3s/ebooks/bookorbit-db`

These directories remain on the WSL virtual disk and are not backups. Removing
the Tanka resources does not remove them automatically.
