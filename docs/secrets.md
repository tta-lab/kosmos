# Secrets

This stage supports secrets only on `kosmos-wsl`.

Private keys and plaintext secrets must never be committed. Agents must not read,
decrypt, print, grep, diff, migrate, or inspect plaintext secret files.

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
- `secrets/env.age`
- `secrets/kube-config.age`
- `secrets/sops-age-keys.age`
- `secrets/woodpecker-server-env.age`
- `secrets/woodpecker-postgres-env.age`
- `secrets/deepseek-key.age`
- `secrets/miniflux-password.age`
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
- `/home/neil/.config/deepseek/key` (a raw DeepSeek key, injected into
  `dsh.service` as `DEEPSEEK_API_KEY`)
- `/home/neil/.config/miniflux/password` (read only by the DSH Miniflux MCP
  wrapper as `MINIFLUX_PASSWORD`)
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
agenix -e secrets/env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/kube-config.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/sops-age-keys.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/woodpecker-server-env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/woodpecker-postgres-env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/deepseek-key.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/miniflux-password.age -i ~/.ssh/agenix_ed25519
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

## DeepSeek Harness

`dsh.service` reads the existing agenix-managed
`/home/neil/.config/deepseek/key` at process start and injects it as
`DEEPSEEK_API_KEY`. The secret must contain only the raw key, not an
`DEEPSEEK_API_KEY=` assignment. To rotate it without exposing it in a shell
history, edit the encrypted file and then deploy:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/deepseek-key.age -i ~/.ssh/agenix_ed25519
nh os switch . -H wsl
```

The remote DSH Models and Settings APIs intentionally remain unavailable: the
upstream application restricts credential and configuration writes to loopback.

## Miniflux MCP

The Home Manager-deployed `/home/neil/.local/bin/miniflux-mcp-wrapper` reads
`/home/neil/.config/miniflux/password` and starts the host-managed
`/home/neil/go/bin/miniflux-mcp` child for DSH. DSH receives only the
non-secret Miniflux URL and username from its Cordis overlay.

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
