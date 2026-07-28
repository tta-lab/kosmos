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
          auto_https off
        }

        :17480 {
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

          handle {
            respond "unknown host" 421
          }
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
            image: 'caddy:2.10.0-alpine',
            args: ['caddy', 'run', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile'],
            ports: [{
              name: 'http',
              containerPort: 17480,
              hostPort: 17480,
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
            volumeMounts: [{ name: 'config', mountPath: '/etc/caddy/Caddyfile', subPath: 'Caddyfile', readOnly: true }],
          }],
          volumes: [{ name: 'config', configMap: { name: 'canonical-gateway' } }],
        },
      },
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
