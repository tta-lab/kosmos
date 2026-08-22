# Nix-managed Chromium for agent-browser

## Decision

The original investigation considered extending `programs.nix-ld.libraries` so
agent-browser's downloaded Chrome for Testing could run. The user chose the
lower-maintenance alternative: use Nix's Chromium wrapper as agent-browser's
local browser instead.

## Evidence

- The downloaded Chromium failed a loopback screenshot smoke test with
  `libglib-2.0.so.0` missing. Nix-ld was configured correctly, but its shared
  library namespace did not contain that library.
- The installed `agent-browser 0.34.0` supports all of:
  `--executable-path`, `AGENT_BROWSER_EXECUTABLE_PATH`, and the
  `executablePath` config key. Its precedence is user config, project config,
  environment, then CLI flags.
- The pinned Nix `pkgs.chromium` wrapper was launched via
  `--executable-path` in an isolated loopback fixture and produced a nonempty
  screenshot. Agent-browser is a native CDP client, so it has no runtime
  Playwright-driver version lock.

## Declarative design

Add stable `pkgs.chromium` to the system package set. Configure the browser in
`home.sessionVariables` with the stable active-system path:

```nix
AGENT_BROWSER_EXECUTABLE_PATH = "/run/current-system/sw/bin/chromium";
```

This avoids an update-sensitive `/nix/store` hash and follows the repository's
owner for non-secret interactive settings. It also overrides a local
`agent-browser.json`, which should not control an executable path for arbitrary
worktrees.

Do not add browser libraries to the shared nix-ld path. Keep the existing
nix-ld configuration unchanged because it may serve other foreign binaries.
Use `pkgs.chromium`, rather than `playwright-driver.browsers`: the latter has
versioned artifact paths and a second Playwright-specific update contract.

## Trade-offs and verification

This reduces ABI-maintenance surface but adds Chromium to the system closure.
The downloaded cache is retained during rollout and may be removed only after a
deployed smoke test succeeds and its removal is explicitly accepted.

After each Nix or agent-browser upgrade, use a fresh named session to launch a
loopback-only fixture and save a nonempty screenshot. Existing browser daemons
continue using their already selected executable; do not close unrelated user
sessions to switch them.

## Sources

- [agent-browser configuration](https://github.com/vercel-labs/agent-browser/blob/main/docs/src/app/configuration/page.mdx)
- [Nixpkgs Chromium wrapper](https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/applications/networking/browsers/chromium/default.nix)
- [NixOS nix-ld module](https://github.com/NixOS/nixpkgs/blob/nixos-25.05/nixos/modules/programs/nix-ld.nix)
