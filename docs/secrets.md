# Secrets

This stage supports secrets only on `kosmos-wsl`.

Private keys and plaintext secrets must never be committed. Agents must not read,
decrypt, print, grep, diff, migrate, or inspect plaintext secret files.

## Keys

`kosmos-wsl` decrypts secrets with:

```bash
/etc/ssh/ssh_host_ed25519_key
```

The matching public key is listed in `secrets/secrets.nix`.

If you add a normal user SSH key later, add its public key to
`secrets/secrets.nix`, then rekey from the secrets directory:

```bash
cd /home/neil/code/projects/tta-lab/kosmos/secrets
agenix -r
```

## Secret Files

Encrypted files live in `secrets/` and are safe to commit:

- `secrets/ttal.env.age`
- `secrets/lenos-config.json.age`
- `secrets/kube-config.age`

They decrypt to:

- `/home/neil/.config/ttal/.env`
- `/home/neil/.local/share/lenos/config.json`
- `/home/neil/.kube/config`

`lenos/config.json` in this repo is non-secret and still maps to
`/home/neil/.config/lenos/config.json`.

`einai/config.toml` is not a secret.

## Create Or Edit Secrets

Because no user SSH public key exists in this environment yet, edit with the WSL
host key:

```bash
cd /home/neil/code/projects/tta-lab/kosmos/secrets
sudo EDITOR="$EDITOR" agenix -e ttal.env.age -i /etc/ssh/ssh_host_ed25519_key
sudo EDITOR="$EDITOR" agenix -e lenos-config.json.age -i /etc/ssh/ssh_host_ed25519_key
sudo EDITOR="$EDITOR" agenix -e kube-config.age -i /etc/ssh/ssh_host_ed25519_key
sudo chown neil:users ttal.env.age lenos-config.json.age kube-config.age
```

After creating or editing encrypted files, apply the WSL config:

```bash
cd /home/neil/code/projects/tta-lab/kosmos
sudo nixos-rebuild switch --flake .#wsl
```
