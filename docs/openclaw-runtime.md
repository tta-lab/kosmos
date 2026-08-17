# OpenClaw runtime and session routing

This document records the local OpenClaw choices that differ from upstream defaults, why they exist, and how to verify or remove them.

## Invariants

- Neil's Telegram DM uses one durable conversation: `agent:main:direct:845849177`.
- Scheduled companionship must read and write that same conversation, not `agent:main:main` or a `cron:...:run:...` session.
- The morning greeting may use only the fixed conversation and relevant files under `~/.openclaw/workspace/memory/`. It must not carry dated facts in the automation declaration.
- Agent `exec` commands use zsh even though Neil's login shell is fish.
- Telegram delivery is best-effort until the Mihomo route is made reliable; a successful model turn does not prove Telegram accepted the outbound message.

## Configuration owners

| Concern | Persistent owner | Live state |
| --- | --- | --- |
| Gateway config | `openclaw/openclaw.jsonnet` | `~/.openclaw/openclaw.json` after `just openclaw-deploy` |
| Gateway environment and secrets | `scripts/openclaw-gateway-wrapper` | `openclaw-gateway.service` process environment |
| Morning and direct heartbeat schedules | Gateway automation database | `openclaw automations list --json` |
| Conversation transcripts and session rows | OpenClaw agent SQLite store | `~/.openclaw/agents/main/agent/openclaw-agent.sqlite` |

Do not hand-edit the generated JSON or SQLite database. Use the Jsonnet deploy path and OpenClaw automation commands.

## Why the Gateway forces zsh

OpenClaw's exec runtime chooses its command shell from the Gateway process's `SHELL`. The systemd service inherited Neil's fish login shell, so generated POSIX/zsh commands could be parsed as fish.

`scripts/openclaw-gateway-wrapper` exports:

```sh
SHELL=/etc/profiles/per-user/neil/bin/zsh
```

This changes the shell used by the OpenClaw Gateway and its agent exec commands. It does not change Neil's interactive login shell.

Verify after a restart:

```sh
pid=$(systemctl --user show openclaw-gateway.service -p MainPID --value)
tr '\0' '\n' </proc/$pid/environ | grep '^SHELL='
```

## Why Telegram keeps a per-peer session

The config intentionally retains:

```json
{ "session": { "dmScope": "per-peer" } }
```

This gives Neil's Telegram identity a stable direct session and a stable user-scoped Hindsight bank. Its key is:

```text
agent:main:direct:845849177
```

Changing `dmScope` to `main` would route future DMs to `agent:main:main` and strand the current direct conversation history. Do not use that as a shortcut for heartbeat routing.

## Why built-in heartbeat is disabled

On OpenClaw `2026.8.1-beta.2`, `agents.defaults.heartbeat.session` accepts the direct session key, but the system-owned heartbeat automation is materialized with `sessionTarget: "main"`. Its replies therefore use `agent:main:main`. System-owned heartbeat jobs reject manual edits.

That caused a heartbeat to conclude that Neil had been absent for two days even though the Telegram direct session had recent messages.

The declarative config therefore sets:

```json
{ "agents": { "defaults": { "heartbeat": { "every": "0m" } } } }
```

A user-owned automation named `Heartbeat (direct)` replaces it:

- declaration key: `yuki-heartbeat-direct`
- schedule: hourly from 11:00 through 22:00, `Asia/Taipei`
- payload: `agentTurn`
- session target: `session:agent:main:direct:845849177`
- delivery: Telegram DM `845849177`, best effort

The normal reply layer suppresses a response consisting only of `HEARTBEAT_OK`.

This is a version-specific workaround. After an OpenClaw upgrade, test whether a built-in heartbeat with an explicit `heartbeat.session` actually writes to the direct session. Only then remove the custom automation and restore `heartbeat.every`.

## Morning greeting

The `早安问候` automation runs at 07:22 in `Asia/Taipei`. It is an `agentTurn` with the persistent target:

```text
session:agent:main:direct:845849177
```

A `systemEvent` with `sessionTarget: main` must not be used here: previous runs created `agent:main:cron:<job-id>:run:<timestamp>` sessions.

### Context policy

The morning prompt must use only:

1. the current fixed-session transcript supplied to the agent; and
2. relevant Markdown files under `~/.openclaw/workspace/memory/`.

It must not:

- read other sessions or old cron-run transcripts;
- use web, FlickNote, or unrelated external sources;
- embed yesterday-specific facts in the persistent job definition;
- guess when a relevant fact cannot be verified.

If neither the fixed session nor memory files contain a reliable detail from yesterday or last night, it should send a simple warm greeting without pretending to remember one.

## Deploy and inspect

Deploy repository-owned config and restart the Gateway:

```sh
just openclaw-deploy
```

Inspect the effective config without exposing secrets:

```sh
jq '{dmScope:.session.dmScope, heartbeat:.agents.defaults.heartbeat}' \
  ~/.openclaw/openclaw.json
```

Inspect the relevant automation contracts:

```sh
scripts/openclaw-gateway-wrapper automations list --json |
  jq '.jobs[] |
      select(.declarationKey == "yuki-heartbeat-direct" or .name == "早安问候") |
      {name, declarationKey, enabled, schedule, sessionTarget, sessionKey,
       payloadKind: .payload.kind, delivery}'
```

Expected for both user-facing schedules:

```text
sessionTarget = session:agent:main:direct:845849177
sessionKey    = agent:main:direct:845849177
payloadKind   = agentTurn
```

Check recent run routing:

```sh
scripts/openclaw-gateway-wrapper automations runs --id <job-id> --json |
  jq '.entries[] | {runAtIso, status, sessionKey, deliveryStatus, error}'
```

A new run must not have a session key containing `:cron:`.

## Delivery caveat

The Gateway reaches Telegram through Mihomo at `127.0.0.1:7890`. Intermittent Telegram API timeouts have left deliveries in `send_attempt_started`; OpenClaw refuses blind replay because it cannot distinguish a dropped message from a successful but unacknowledged send. Session correctness and delivery correctness must therefore be checked separately.

Useful log query:

```sh
journalctl --user -u openclaw-gateway.service --since today --no-pager |
  grep -E 'outbound send ok|final reply failed|refusing blind replay|sessionKey='
```

## Rollback

- Remove the zsh override to restore inherited-shell behavior.
- Disable or delete `Heartbeat (direct)` before re-enabling built-in heartbeat, otherwise both schedules can run.
- Restore `heartbeat.every: "1h"` only after verifying explicit direct-session routing on the installed OpenClaw version.
- Keep `dmScope: "per-peer"` unless conversation history is deliberately migrated.
