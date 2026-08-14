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
- `secrets/hindsight-env.age`
- `secrets/openclaw-deepseek-key.age`

They decrypt to:

- `/home/neil/.config/ttal/.env`
- `/home/neil/.config/env` (Fish-only shell secrets)
- `/home/neil/.kube/config`
- `/home/neil/.config/sops/age/keys.txt`
- `/run/agenix/woodpecker-server-env` (root-owned, synchronized to the local
  K3s `devops/woodpecker-server-env` Secret by
  `woodpecker-secret-sync.service`)
- `/run/agenix/hindsight-env` (root-owned, synchronized to the local K3s
  `hindsight/hindsight-env` Secret by `hindsight-secret-sync.service`)
- `/home/neil/.config/openclaw/deepseek-key` (a raw DeepSeek key, injected into
  `dsh.service` as `DEEPSEEK_API_KEY`)

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
agenix -e secrets/hindsight-env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/openclaw-deepseek-key.age -i ~/.ssh/agenix_ed25519
```

Before deploying a changed Woodpecker secret, Neil must validate that all
three required keys exist exactly once and are non-empty. This command prints
only the validation result, never the values:

```bash
agenix -d secrets/woodpecker-server-env.age -i ~/.ssh/agenix_ed25519 \
  | bash scripts/sync-woodpecker-secret --validate-only -
```

Commit encrypted files after editing:

```bash
git add secrets/ttal.env.age secrets/env.age secrets/kube-config.age secrets/sops-age-keys.age secrets/woodpecker-server-env.age
git commit -m "chore(secrets): update encrypted secrets"
```

## DeepSeek Harness

`dsh.service` reads the existing agenix-managed
`/home/neil/.config/openclaw/deepseek-key` at process start and injects it as
`DEEPSEEK_API_KEY`. The secret must contain only the raw key, not an
`DEEPSEEK_API_KEY=` assignment. To rotate it without exposing it in a shell
history, edit the encrypted file and then deploy:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/openclaw-deepseek-key.age -i ~/.ssh/agenix_ed25519
nh os switch . -H wsl --ask
```

The remote DSH Models and Settings APIs intentionally remain unavailable: the
upstream application restricts credential and configuration writes to loopback.

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
nh os switch . -H wsl --ask
```

The rebuild restarts `woodpecker-secret-sync.service` when
`secrets/woodpecker-server-env.age` changes. The unit uses only
`/etc/rancher/k3s/k3s.yaml` and refuses a non-local API server. Verify it
without reading the secret:

```bash
systemctl status woodpecker-secret-sync.service --no-pager
KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
  kubectl get secret woodpecker-server-env -n devops -o name
```
