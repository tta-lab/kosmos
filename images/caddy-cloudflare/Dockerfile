FROM caddy:2.10.0-builder AS builder
ARG GOPROXY=https://proxy.golang.org
ARG GOSUMDB=sum.golang.org
RUN xcaddy build v2.10.0 --with github.com/caddy-dns/cloudflare@v0.2.4
FROM caddy:2.10.0-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
