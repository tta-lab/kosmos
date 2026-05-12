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

They decrypt to:

- `/home/neil/.config/ttal/.env`
- `/home/neil/.kube/config`

`lenos/config.json` in this repo is non-secret and still maps to
`/home/neil/.config/lenos/config.json`.

The secret Lenos config at `/home/neil/.local/share/lenos/config.json` is not
managed by agenix yet.

`einai/config.toml` is not a secret.

## Create Or Edit Secrets

Edit with Neil's agenix key:

```bash
cd /home/neil/code/projects/tta-lab/kosmos/secrets
agenix -e ttal.env.age -i ~/.ssh/agenix_ed25519
agenix -e kube-config.age -i ~/.ssh/agenix_ed25519
```

After creating or editing encrypted files, apply the WSL config:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
sudo nixos-rebuild switch --flake .#wsl
```
