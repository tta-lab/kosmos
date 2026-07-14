# Seafarer edge routing

Seafarer uses the existing `kepos` Cloudflare Tunnel instead of running its
own `cloudflared` container.

The host-side contract is:

- `127.0.0.1:18080` — Seafile
- `127.0.0.1:18081` — SeaDoc
- `127.0.0.1:18082` — OnlyOffice
- `127.0.0.1:18083` — Nginx path router for `seafile.guion.io`

Nginx sends `/sdoc-server` and `/socket.io` requests to SeaDoc. All other
requests for `seafile.guion.io` go to Seafile. The tunnel sends
`onlyoffice.guion.io` straight to the OnlyOffice loopback port.

Do not move the Cloudflare DNS records until the Seafarer Compose deployment
publishes the three upstream ports on loopback. After both sides are deployed,
point `seafile.guion.io` and `onlyoffice.guion.io` at the existing `kepos`
tunnel and verify both public endpoints before removing the old tunnel.
