# WezTerm WSL Mux

This setup uses the WezTerm GUI on macOS and a WezTerm mux server inside
`kosmos-wsl`. The connection is SSH-based, using the macOS SSH alias
`frp-fast`, so it works through the same SSH/frp path used for normal remote
access.

There is no local WSL unix socket in this design. The WSL2 unix-socket caveat
only matters for a Windows GUI trying to connect to a WSL socket through
`/mnt/c`. Here the Mac GUI connects over SSH, and WezTerm starts the remote mux
server on the WSL side.

## WSL Side

Nix installs the remote pieces on `kosmos-wsl`:

- `pkgsUnstable.wezterm`
- `pkgsUnstable.wezterm.terminfo`
- `ttal-wezterm-projects`

The WSL server-side WezTerm config is:

```text
wezterm/wsl-mux-server.lua
```

Home Manager installs it to:

```text
~/.config/wezterm/wezterm.lua
```

This file is intentionally small. It only covers remote/server concerns, such
as the default shell used by panes that run inside WSL. It does not define SSH
domains, fonts, macOS window behavior, or picker key bindings.

`ttal-wezterm-projects --choices` reads:

```bash
ttal project list --json
```

and returns WezTerm `InputSelector` choices. The macOS config calls this helper
over SSH when opening the project picker.

Apply the WSL config after merging:

```bash
nixos-rebuild switch --flake .#wsl
```

Then check the remote side:

```bash
wezterm --version
ttal-wezterm-projects --choices
```

## macOS Side

The macOS GUI config template is:

```text
wezterm/macos-ssh-wsl-mux.lua
```

Use it as your macOS `~/.wezterm.lua` or import/copy the parts you need into
your existing config.

The template keeps local GUI concerns on macOS:

- theme, font, padding, tab behavior
- right-click paste
- fullscreen startup
- key bindings

It also defines one SSH mux domain:

```lua
name = "kosmos-wsl"
remote_wezterm_path = "/run/current-system/sw/bin/wezterm"
multiplexing = "WezTerm"
```

This file is the client-side config. It owns the GUI behavior and the SSH mux
client settings. Keep it separate from the WSL server config.

## SSH/frp

Prefer the existing macOS SSH config alias. The Lua config uses `frp-fast` for
both WezTerm mux connection and project-list loading.

Example:

```sshconfig
Host frp-fast
  HostName <frp-host>
  Port <frp-ssh-port>
  User neil
  IdentityFile ~/.ssh/<key>
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Check plain SSH first:

```bash
ssh frp-fast 'wezterm --version && ttal-wezterm-projects --choices'
```

Then connect the WezTerm mux domain:

```bash
wezterm connect kosmos-wsl
```

You can also spawn into the domain from an existing WezTerm GUI:

```bash
wezterm cli spawn --domain-name kosmos-wsl
```

If you use a different SSH alias, set this before launching WezTerm:

```bash
export KOSMOS_WEZTERM_SSH_HOST=<ssh-alias>
```

If the WezTerm domain name should differ from the SSH alias:

```bash
export KOSMOS_WEZTERM_DOMAIN=<domain-name>
```

If the remote address should differ from the SSH alias:

```bash
export KOSMOS_WEZTERM_REMOTE=<host-or-host-port>
```

## Project Picker

In the macOS template:

- `Ctrl+Shift+P` opens the TTAL project picker.
- The picker calls `ssh frp-fast ttal-wezterm-projects --choices`.
- Picking a project runs `SwitchToWorkspace` in the `kosmos-wsl` domain.
- The workspace name is derived from the TTAL alias.
- The first pane starts in the TTAL project path on WSL.

`Alt+9` opens WezTerm's workspace launcher.

The picker does one SSH round trip each time it opens. That keeps the list fresh
with `ttal project list --json`, and avoids syncing a project cache onto macOS.
If it feels slow later, add a short-lived cache on the macOS side; do not move
TTAL project parsing into the GUI config.

## SSH Alias And Domain Name

The SSH alias and WezTerm domain name are different names for different layers.

`frp-fast` is the macOS SSH alias. It belongs to OpenSSH and describes how to
reach WSL through frp. The project picker also uses it when it shells out to:

```bash
ssh frp-fast ttal-wezterm-projects --choices
```

`kosmos-wsl` is the WezTerm domain name. It belongs to WezTerm and names the
remote mux domain inside the GUI. WezTerm uses that name for commands like:

```bash
wezterm connect kosmos-wsl
wezterm cli spawn --domain-name kosmos-wsl
```

Keeping the domain name as `kosmos-wsl` makes WezTerm UI labels describe the
remote environment, while `frp-fast` remains the transport alias.

## What Must Stay Aligned

The macOS config and WSL config are coupled at these points:

- SSH alias: default `frp-fast`
- WezTerm domain name: default `kosmos-wsl`
- Remote WezTerm path: `/run/current-system/sw/bin/wezterm`
- Remote helper path: `ttal-wezterm-projects` must be in the SSH login `PATH`

They do not need identical Lua files. The WSL side uses
`wezterm/wsl-mux-server.lua` for server defaults. The macOS side uses
`wezterm/macos-ssh-wsl-mux.lua` for GUI and SSH mux client behavior.

If the picker fails but `wezterm connect kosmos-wsl` works, test:

```bash
ssh frp-fast 'command -v ttal-wezterm-projects && ttal-wezterm-projects --choices'
```

If connection fails before any shell appears, test:

```bash
ssh frp-fast 'command -v wezterm && /run/current-system/sw/bin/wezterm --version'
```
