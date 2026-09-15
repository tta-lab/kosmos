# Retired DeepSeek Harness deployment

The loopback DSH production service on port 3080 and its Kepos `dsh` service
were retired after the Codex for Love dev and prod services replaced them.
Kosmos no longer installs, starts, publishes, or verifies that runtime.

The retained DSH state under `~/.local/state/dsh` is historical data and is not
removed by Nix activation. The separately provisioned development DSH on port
3081 is outside this retired production deployment.
