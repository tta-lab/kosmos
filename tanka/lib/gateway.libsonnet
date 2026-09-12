local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-devops',
};

local gatewayLabels = labels('canonical-gateway');

{
  coreDnsOverrides: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'coredns-custom',
      namespace: 'kube-system',
    },
    data: {
      'kosmos.override': |||
        rewrite name exact forgejo.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact woodpecker.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact ente.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact ente-storage.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact bookorbit.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact cloudreve.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact anki.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact memos.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact miniflux.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact hindsight.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact hindsightui.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact codex-bridge.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact erpnext.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact grafana.localhost canonical-gateway.devops.svc.cluster.local
        rewrite name exact impri.localhost canonical-gateway.devops.svc.cluster.local
      |||,
    },
  },
  gatewayConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'canonical-gateway',
      namespace: 'devops',
      labels: gatewayLabels,
    },
    data: {
      Caddyfile: |||
        {
          admin off
          auto_https disable_redirects
          servers {
            protocols h1 h2
          }
        }

        http://:17480 {
          bind 0.0.0.0

          @forgejo host forgejo.localhost
          handle @forgejo {
            reverse_proxy forgejo:3000
          }

          @woodpecker host woodpecker.localhost
          handle @woodpecker {
            reverse_proxy woodpecker:8000
          }

          @ente host ente.localhost
          handle @ente {
            reverse_proxy museum.photos.svc.cluster.local:8080
          }

          @enteStorage host ente-storage.localhost
          handle @enteStorage {
            reverse_proxy garage.photos.svc.cluster.local:3900
          }

          @bookorbit host bookorbit.localhost
          handle @bookorbit {
            reverse_proxy bookorbit.ebooks.svc.cluster.local:3000
          }

          @cloudreve host cloudreve.localhost
          handle @cloudreve {
            reverse_proxy cloudreve.cloudreve.svc.cluster.local:5212
          }

          @anki host anki.localhost
          handle @anki {
            reverse_proxy anki-sync-server.anki.svc.cluster.local:8080 {
              transport http {
                read_buffer 512k
              }
            }
          }

          @memos host memos.localhost
          handle @memos {
            reverse_proxy memos.notes.svc.cluster.local:5230
          }

          @miniflux host miniflux.localhost
          handle @miniflux {
            reverse_proxy miniflux.feeds.svc.cluster.local:8080
          }

          @hindsight host hindsight.localhost
          handle @hindsight {
            reverse_proxy hindsight.hindsight.svc.cluster.local:8888
          }

          @hindsightui host hindsightui.localhost
          handle @hindsightui {
            reverse_proxy hindsight.hindsight.svc.cluster.local:9999
          }

          @codexBridge host codex-bridge.localhost codex-bridge.kepos.internal
          handle @codexBridge {
            reverse_proxy codex-bridge.codex-bridge.svc.cluster.local:8787
          }

          @erpnext host erpnext.localhost
          handle @erpnext {
            reverse_proxy erpnext.erpnext.svc.cluster.local:8080
          }

          @grafana host grafana.localhost
          handle @grafana {
            reverse_proxy grafana.observability.svc.cluster.local:3000
          }

          @impri host impri.localhost
          handle @impri {
            reverse_proxy impri-ui.impri.svc.cluster.local:8080
          }

          @clipcascade host clipcascade.localhost
          handle @clipcascade {
            reverse_proxy clipcascade.clipcascade.svc.cluster.local:8080 {
              header_up Host clipcascade.localhost:17480
            }
          }

          handle {
            respond "unknown host" 421
          }
        }

        https://ddns-smoke.guion.io:18443 {
          bind 0.0.0.0
          tls {
            issuer acme {
              dir https://acme-v02.api.letsencrypt.org/directory
              dns cloudflare {env.CF_API_TOKEN}
            }
          }
          header Content-Type "text/html; charset=utf-8"
          header Cache-Control "no-store"
          respond "<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>DDNS smoke</title><h1>DDNS smoke OK</h1><p>ddns-smoke.guion.io</p></html>" 200
        }
      |||,
    },
  },
  gatewayDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'canonical-gateway',
      namespace: 'devops',
      labels: gatewayLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: gatewayLabels },
      template: {
        metadata: { labels: gatewayLabels },
        spec: {
          containers: [{
            name: 'caddy',
            image: 'localhost/kosmos/caddy-cloudflare:2.10.0-cf0.2.4',
            imagePullPolicy: 'Never',
            env: [{
              name: 'CF_API_TOKEN',
              valueFrom: { secretKeyRef: { name: 'caddy-cloudflare', key: 'CF_API_TOKEN' } },
            }],
            args: ['caddy', 'run', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile', '--watch'],
            ports: [{
              name: 'http',
              containerPort: 17480,
              hostPort: 17480,
              hostIP: '127.0.0.1',
            }, {
              name: 'https-public',
              containerPort: 18443,
              hostPort: 18443,
              hostIP: '127.0.0.1',
            }],
            readinessProbe: {
              tcpSocket: { port: 'http' },
              initialDelaySeconds: 2,
              periodSeconds: 5,
            },
            resources: {
              requests: { cpu: '20m', memory: '32Mi' },
              limits: { cpu: '250m', memory: '128Mi' },
            },
            volumeMounts: [
              { name: 'config', mountPath: '/etc/caddy', readOnly: true },
              { name: 'data', mountPath: '/data' },
            ],
          }],
          volumes: [
            { name: 'config', configMap: { name: 'canonical-gateway' } },
            { name: 'data', persistentVolumeClaim: { claimName: 'canonical-gateway-data' } },
          ],
        },
      },
    },
  },
  gatewayData: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: { name: 'canonical-gateway-data', namespace: 'devops' },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'local-path',
      resources: { requests: { storage: '1Gi' } },
    },
  },
  gatewayService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'canonical-gateway',
      namespace: 'devops',
      labels: gatewayLabels,
    },
    spec: {
      selector: gatewayLabels,
      ports: [{ name: 'http', port: 17480, targetPort: 'http' }],
    },
  },
}
