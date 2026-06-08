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

Only public keys are listed in `secrets/secrets.nix`.

If you change recipients, rekey from the secrets directory:

```bash
cd /home/neil/code/projects/tta-lab/kosmos/secrets
agenix -r -i ~/.ssh/agenix_ed25519
```

## Secret Files

Encrypted files live in `secrets/` and are safe to commit:

- `secrets/ttal.env.age`
- `secrets/kube-config.age`
- `secrets/ttal-kubeconfig.age`
- `secrets/sops-age-keys.age`
- `secrets/mihomo-config.age`

They decrypt to:

- `/home/neil/.config/ttal/.env`
- `/home/neil/.kube/config`
- `/home/neil/.ttal/kubeconfig`
- `/home/neil/.config/sops/age/keys.txt`
- `/run/agenix/mihomo-config` (root-owned, read by mihomo systemd service)

`lenos/config.json` in this repo is non-secret and still maps to
`/home/neil/.config/lenos/config.json`.

The secret Lenos config at `/home/neil/.local/share/lenos/config.json` is not
managed by agenix yet.

`einai/config.toml` is not a secret.

## Create Or Edit Secrets

From the repo root, run `agenix` directly (the rules file `secrets.nix` lives at repo root):

```bash
cd /home/neil/code/projects/tta-lab/kosmos
agenix -e secrets/ttal.env.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/kube-config.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/ttal-kubeconfig.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/sops-age-keys.age -i ~/.ssh/agenix_ed25519
agenix -e secrets/mihomo-config.age -i ~/.ssh/agenix_ed25519
```

Commit encrypted files after editing:

```bash
git add secrets/ttal.env.age secrets/kube-config.age secrets/ttal-kubeconfig.age secrets/sops-age-keys.age secrets/mihomo-config.age
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
