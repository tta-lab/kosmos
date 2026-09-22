# Secrets

This stage supports secrets only on `kosmos-wsl`.

Private keys and plaintext secrets must never be committed. Agents must not read,
decrypt, print, grep, diff, migrate, or inspect plaintext secret files.

## Declare and consume

1. Register `secrets/<name>.age` with its recipients in `secrets.nix`.
2. Declare the secret in `modules/wsl/secrets.nix`, setting `file`, `owner`,
   `group`, and `mode`. Use agenix's default `path` for runtime consumers:

   ```nix
   age.secrets."example.env" = {
     file = ../../secrets/example.env.age;
     owner = "neil";
     group = "users";
     mode = "0400";
   };
   ```

3. Reference `config.age.secrets."example.env".path` from consumers.
   Systemd services use `EnvironmentFile` for `NAME=value` files. For Home
   Manager nested inside a NixOS module, capture this path in the outer
   `let`, or use the Home Manager module's `osConfig` argument. Its own
   `config` refers to Home Manager options, not NixOS options.
4. Give Neil the exact `agenix -e secrets/<name>.age` command and expected
   plaintext format. Commit only the encrypted `.age` file. Follow the
   repository's existing optional-secret convention when the file has not
   been provisioned; consumers check the declared `config.age.secrets`
   attribute rather than independently checking the filesystem.

Nix may interpolate a secret's runtime **path**, never its plaintext content.
Keep secrets out of `home.sessionVariables`, unit `Environment`, generated
Nix-store files, and `builtins.readFile`. Interactive shells load secret
values at runtime; use parsing appropriate to the file format. A systemd
environment file is not a Fish script. See [Meilisearch](meilisearch.md) for
the shared Fish/service environment file and its single-line format.

Only override `path` when an application requires a fixed external location,
such as `~/.kube/config`. Within `age.secretsDir`, use the default
`${age.secretsDir}/${name}`. A different basename there creates a broken
activation sequence: agenix writes the alias into the old generation,
switches the directory link, then removes that old generation. The secret
decrypts successfully but its custom alias disappears.

## Keys

`kosmos-wsl` decrypts deployed secrets with:

```bash
/etc/ssh/ssh_host_ed25519_key
```

Neil edits secrets with:

```bash
~/.ssh/agenix_ed25519
```

Only public keys are listed in `secrets.nix` at the repo root.

If you change recipients, rekey from the repo root:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -r -i ~/.ssh/agenix_ed25519
```

## Secret Files

Encrypted files live in `secrets/` and are safe to commit:

- `secrets/ttal.env.age`
- `secrets/cloudflare-ddns-token.age`
- `secrets/env.age`
- `secrets/kube-config.age`
- `secrets/sops-age-keys.age`
- `secrets/woodpecker-server-env.age`
- `secrets/woodpecker-postgres-env.age`
- `secrets/soniox-key.age`
- `secrets/volcengine-key.age`
- `secrets/forgejo-r2-backup.age` (optional; encrypted and safe to commit;
  enables the Forgejo source-recovery backup secret synchronizer when the
  operator creates it)

They decrypt to:

- `/home/neil/.config/ttal/.env`
- `/home/neil/.config/env` (Fish-only shell secrets)
- `/home/neil/.kube/config`
- `/home/neil/.config/sops/age/keys.txt`
- `/run/agenix/woodpecker-server-env` (root-owned, synchronized to the local
  K3s `devops/woodpecker-server-env` Secret by
  `woodpecker-secret-sync.service`)
- `/run/agenix/woodpecker-postgres-env` (root-owned, synchronized to the local
  K3s `devops/woodpecker-postgres-env` Secret by the same service)
- `/home/neil/.config/soniox/key` (provider-owned Soniox credential retained
  for a future voice integration)
- `/home/neil/.config/volcengine/key` (provider-owned Volcengine credential
  retained for a future voice integration)
- `/run/agenix/forgejo-r2-backup` (root-owned R2/restic environment, synchronized
  to the local `devops/forgejo-r2-backup` Kubernetes Secret by
  `forgejo-r2-backup-secret-sync.service`)

`lenos/config.json` in this repo is non-secret and still maps to
`/home/neil/.config/lenos/config.json`.

The secret Lenos config at `/home/neil/.local/share/lenos/config.json` is not
managed by agenix yet.

`secrets/env.age` is a Fish source file, currently holding the Exa API key. It
must use Fish `set -gx` syntax and is sourced only by Fish; Zsh and systemd
services do not read it. Keep only shell-only secrets there. Non-secret
variables belong in Nix according to the [environment variable ownership
guide](environment.md).

## Create Or Edit Secrets

From the repo root, run `agenix` directly (the rules file `secrets.nix` lives at repo root):

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/ttal.env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/cloudflare-ddns-token.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/kube-config.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/sops-age-keys.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/woodpecker-server-env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/woodpecker-postgres-env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/soniox-key.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/volcengine-key.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/forgejo-r2-backup.age -i ~/.ssh/agenix_ed25519
```

The optional Forgejo source-recovery file must contain only the four required
environment assignments (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`RESTIC_PASSWORD`, and `RESTIC_REPOSITORY` using restic `s3:` syntax). Keep the
restic password in an independent password-manager entry before creating the
file. Do not place values in Nix, Jsonnet, source control, logs, or this
documentation. The synchronizer validates the encrypted file after the WSL
switch and creates the Kubernetes Secret only on the local k3s API. The `.age`
file is the encrypted artifact: after editing it with `agenix`, commit the
encrypted file and never commit a decrypted copy.

Before deploying changed Woodpecker secrets, Neil must validate both encrypted
files. The server file contains the three Forgejo/agent keys; the PostgreSQL
file contains `POSTGRES_PASSWORD` and `WOODPECKER_DATABASE_DATASOURCE`. This
command prints only the validation result, never the values:

```bash
bash -c '
  bash scripts/sync-woodpecker-secret --validate-only \
    <(agenix -d secrets/woodpecker-server-env.age -i ~/.ssh/agenix_ed25519) \
    <(agenix -d secrets/woodpecker-postgres-env.age -i ~/.ssh/agenix_ed25519)
'
```

Commit encrypted files after editing:

```bash
git add secrets/ttal.env.age secrets/env.age secrets/kube-config.age secrets/sops-age-keys.age secrets/woodpecker-server-env.age secrets/woodpecker-postgres-env.age secrets/forgejo-r2-backup.age
git commit -m "chore(secrets): update encrypted secrets"
```

## Add The Local k3d Cluster

Do not write directly to `/home/neil/.kube/config`; it is managed by agenix.
Merge the k3d `dev` cluster into the encrypted kubeconfig:

```bash
tmp="$(mktemp -d)"
chmod 700 "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd /home/neil/code/projects/tta-lab/kosmos/secrets

agenix -d kube-config.age -i ~/.ssh/agenix_ed25519 > "$tmp/current.yaml"
chmod 600 "$tmp/current.yaml"

k3d kubeconfig get dev > "$tmp/k3d.yaml"

KUBECONFIG="$tmp/current.yaml:$tmp/k3d.yaml" \
  kubectl config view --flatten > "$tmp/merged.yaml"

agenix -e kube-config.age -i ~/.ssh/agenix_ed25519 < "$tmp/merged.yaml"
```

After creating or editing encrypted files, apply the WSL config:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
nh os switch . -H wsl
```

The rebuild restarts `woodpecker-secret-sync.service` when either Woodpecker
encrypted file changes. The unit uses only `/etc/rancher/k3s/k3s.yaml` and
refuses a non-local API server. Verify both synchronized Kubernetes Secrets
without reading them:

```bash
systemctl status woodpecker-secret-sync.service --no-pager
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl get secret woodpecker-server-env woodpecker-postgres-env \
    -n devops -o name
```

## Verify activation

Run the Nix checks and system build required by `AGENTS.md`, then activate
with `nh os switch . -H wsl`. A successful build or a "decrypting" log line
does not establish that a consumer can access its secret.

Check the evaluated `.path` with `stat` or `test -r` as the consuming user.
For a missing path, inspect `readlink /run/agenix` and generation directory
metadata using `sudo find`; do not print decrypted files. Compare `name`,
`path`, and the generated activation script before blaming the deploy tool.

For shell variables, start a fresh shell and assert the value is nonempty,
printing only PASS/FAIL. Existing shells retain their old environment;
`exec fish` reloads the secret. To reload Home Manager session variables too,
run `set -e __HM_SESS_VARS_SOURCED; exec fish` in Fish. Restart an affected service to load
its environment file, check its state, and verify an authenticated operation
without logging credentials. Keep this live verification separate from tests:
automated tests use temporary fixtures and must not touch live secrets.

The upstream [agenix module](https://github.com/ryantm/agenix/blob/main/modules/age.nix)
defines the default path and generation-switch ordering; the pinned module
and generated activation script are authoritative for the deployed system.
