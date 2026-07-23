# Seafarer edge routing

Seafarer keeps its host-side path router on loopback. It is not exposed through
the `kepos` Cloudflare Tunnel.

The host-side contract is:

- `127.0.0.1:18080` — Seafile
- `127.0.0.1:18081` — SeaDoc
- `127.0.0.1:18082` — OnlyOffice
- `127.0.0.1:18083` — PDF classifier
- `127.0.0.1:8081` — Caddy path router for `seafile.guion.io`

Caddy sends `/sdoc-server` and `/socket.io` requests to SeaDoc, and `/upload`
and `/upload/*` to the classifier. All other requests for `seafile.guion.io`
go to Seafile. OnlyOffice remains available to local consumers on
`127.0.0.1:18082`; this module does not publish either hostname.
