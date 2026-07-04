# Listen Together Plan

This plan tracks the intended shared listening setup for Kepos.

## Goal

Build a private listen-together room for friends using the existing Navidrome
server at `https://music.guion.io`.

Friends must have Navidrome accounts before joining rooms. There should be no
second account system for the listen-together layer.

## Direction

Use Navidrome as the only source of identity, music metadata, and audio streams.
Use a small listen-together service at `https://party.guion.io` for room state
and playback sync.

Desktop clients can use the listen-together author's Feishin fork first. Mobile
support should come from a Navic fork once the protocol and UX prove useful.

```text
Navidrome
  - user accounts
  - music library
  - Subsonic/OpenSubsonic API

listen-together server
  - room state
  - WebSocket sync
  - validates users against Navidrome/Subsonic
  - no separate users or passwords

Desktop
  - alsoGAMER/Feishin fork

Mobile
  - Kepos/Navic fork with listen-together UI
```

## Why This Shape

This keeps account ownership simple. Friends get one Navidrome account and use
the same credentials for normal listening and shared rooms.

It also avoids adopting a larger product with its own registration, upload,
admin, and email flows. The shared listening service should only coordinate room
state; it should not become another music platform.

## Non-Goals

- Do not add a second account system.
- Do not expose public anonymous rooms.
- Do not require Jellyfin for music rooms.
- Do not build Matrix widget support in the first phase.
- Do not fork both desktop and mobile clients before the sync server is proven.

## Phases

### Phase 1: Server Proof

- Deploy the listen-together server at `party.guion.io`.
- Configure it to authenticate against `music.guion.io`.
- Keep room access limited to users with valid Navidrome credentials.
- Verify room creation, joining, queue sync, play, pause, seek, and next track.

### Phase 2: Desktop Proof

- Build or install the listen-together author's Feishin fork.
- Connect it to `music.guion.io`.
- Connect it to `party.guion.io`.
- Test with at least two desktop clients.

Success means two users can join the same room and stay in sync through normal
playback controls.

### Phase 3: Mobile Client

- Fork Navic.
- Add a minimal listen-together surface:
  - create room
  - join room from link
  - show current queue
  - add songs to queue
  - play, pause, seek, and next
  - leave room
- Reuse Navidrome credentials already configured in the app.

The first mobile version should be small. It should prove that phone playback,
background behavior, lock-screen controls, and reconnects are acceptable before
adding richer room features.

### Phase 4: Matrix Widget

Only after the mobile and web-room behavior is stable, consider an Element
widget. The widget should use the same room protocol and should not introduce
another identity layer.

## Risks

Maintaining client forks is the main cost.

The Feishin fork is useful for desktop validation, but long-term maintenance
depends on how far it drifts from upstream Feishin.

The Navic fork is the bigger commitment. Mobile sync must handle background
playback, network changes, app suspension, stale room state, and lock-screen
controls. This is the main reason to delay the mobile fork until the server and
desktop path are proven.

## Open Questions

- Should `party.guion.io` be protected by Cloudflare Access in addition to
  Navidrome authentication?
- Should room creation be allowed for every Navidrome user, or only selected
  users?
- Should the sync server persist rooms, or should rooms disappear when empty?
- Should guests be allowed to join as listen-only users later?

## First Implementation Target

The first useful milestone is:

```text
Two Navidrome users can use desktop Feishin fork clients to join one
party.guion.io room and listen to music from music.guion.io in sync.
```

That milestone is enough to decide whether the Navic fork is worth starting.
