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
- `secrets/kube-config.age`
- `secrets/sops-age-keys.age`
- `secrets/woodpecker-server-env.age`

They decrypt to:

- `/home/neil/.config/ttal/.env`
- `/home/neil/.kube/config`
- `/home/neil/.config/sops/age/keys.txt`
- `/run/agenix/woodpecker-server-env` (root-owned, synchronized to the local
  K3s `devops/woodpecker-server-env` Secret by
  `woodpecker-secret-sync.service`)

`lenos/config.json` in this repo is non-secret and still maps to
`/home/neil/.config/lenos/config.json`.

The secret Lenos config at `/home/neil/.local/share/lenos/config.json` is not
managed by agenix yet.

## Create Or Edit Secrets

From the repo root, run `agenix` directly (the rules file `secrets.nix` lives at repo root):

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/ttal.env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/kube-config.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/sops-age-keys.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/woodpecker-server-env.age -i ~/.ssh/agenix_ed25519
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
git add secrets/ttal.env.age secrets/kube-config.age secrets/sops-age-keys.age secrets/woodpecker-server-env.age
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
sudo nixos-rebuild switch --flake .#wsl
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
