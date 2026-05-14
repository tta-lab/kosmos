# WezTerm WSL Mux

This setup uses the WezTerm GUI on macOS and a WezTerm mux server inside
`kosmos-wsl`. The connection is SSH-based, using the macOS SSH alias
`kosmos-wsl`, so it works through the same SSH/frp path used for normal remote
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
wezterm/wsl-server.lua
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
wezterm/macos-client.lua
```

Use it as your macOS `~/.wezterm.lua` or import/copy the parts you need into
your existing config.

If you copy it into an existing config, do not append it after an existing
`return config`. In Lua, `return` must be the last statement in the file. Keep
one `local config = { ... }` table and one `return config` at the end, or use
this file as the full macOS config.

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

Prefer the existing macOS SSH config alias. The Lua config uses `kosmos-wsl` for
both WezTerm mux connection and project-list loading.

Example:

```sshconfig
Host kosmos-wsl
  HostName <frp-host>
  Port <frp-ssh-port>
  User neil
  IdentityFile ~/.ssh/<key>
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Check plain SSH first:

```bash
ssh kosmos-wsl 'wezterm --version && ttal-wezterm-projects --choices'
```

Then connect the WezTerm mux domain:

```bash
wezterm connect kosmos-wsl
```

On first connect, WezTerm may log that it cannot connect to a socket like:

```text
/run/user/1000/wezterm/sock
```

and then say it is running `wezterm-mux-server --daemonize`. That is the normal
SSH-domain path when no mux server is already running. Treat it as a problem
only if no window opens or the command exits with a later failure.

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
- `Ctrl+Shift+Alt+P` opens the TTAL project picker with a forced refresh.
- The picker calls `ssh kosmos-wsl ttal-wezterm-projects --choices`.
- Picking a project runs `SwitchToWorkspace` in the `kosmos-wsl` domain.
- Workspace names use exact TTAL aliases.
- The first pane starts in the TTAL project path on WSL.

`Alt+9` opens WezTerm's workspace launcher.

The picker stores the selected alias and path in a hidden ID separated by a tab
character. The tab is not displayed in the picker. It is only how the Lua
callback receives both values after selection. TTAL aliases that contain a tab
or newline are ignored by the helper because they would break that hidden ID
format. Normal aliases such as `ko`, `fb.ai`, `fb-api`, and `foo_bar` are used
as-is.

Projects whose paths do not exist on WSL are skipped. The helper runs on WSL,
so it can check project paths before the macOS GUI tries to spawn a pane with
that path as `cwd`.

The picker caches project choices for one hour on the macOS side. The first
open does one SSH round trip:

```bash
ssh kosmos-wsl ttal-wezterm-projects --choices
```

Then repeated opens use the cache until it expires. Use `Ctrl+Shift+Alt+P` to
force a refresh.

The client config sets WSL HOME and XDG paths when spawning a project pane, so
remote fish sees `/home/neil` rather than the macOS `$HOME`.

## SSH Alias And Domain Name

The SSH alias and WezTerm domain name default to the same string,
`kosmos-wsl`, but they still belong to different layers.

`kosmos-wsl` is the macOS SSH alias. It belongs to OpenSSH and describes how to
reach WSL through frp. The project picker also uses it when it shells out to:

```bash
ssh kosmos-wsl ttal-wezterm-projects --choices
```

`kosmos-wsl` is the WezTerm domain name. It belongs to WezTerm and names the
remote mux domain inside the GUI. WezTerm uses that name for commands like:

```bash
wezterm connect kosmos-wsl
wezterm cli spawn --domain-name kosmos-wsl
```

Using the same default keeps the config easy to read. If the SSH route changes
again, `KOSMOS_WEZTERM_SSH_HOST` can change the OpenSSH alias without changing
the WezTerm domain label.

## What Must Stay Aligned

The macOS config and WSL config are coupled at these points:

- SSH alias: default `kosmos-wsl`
- WezTerm domain name: default `kosmos-wsl`
- Remote WezTerm path: `/run/current-system/sw/bin/wezterm`
- Remote helper path: `ttal-wezterm-projects` must be in the SSH login `PATH`

They do not need identical Lua files. The WSL side uses
`wezterm/wsl-server.lua` for server defaults. The macOS side uses
`wezterm/macos-client.lua` for GUI and SSH mux client behavior.

If the picker fails but `wezterm connect kosmos-wsl` works, test:

```bash
ssh kosmos-wsl 'command -v ttal-wezterm-projects && ttal-wezterm-projects --choices'
```

If connection fails before any shell appears, test:

```bash
ssh kosmos-wsl 'command -v wezterm && /run/current-system/sw/bin/wezterm --version'
```
