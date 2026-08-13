local appLabels = {
  'app.kubernetes.io/name': 'miniflux',
  'app.kubernetes.io/part-of': 'kosmos-feeds',
};

local dbLabels = {
  'app.kubernetes.io/name': 'miniflux-postgres',
  'app.kubernetes.io/part-of': 'kosmos-feeds',
};

{
  minifluxService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'miniflux',
      namespace: 'feeds',
      labels: appLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: appLabels,
      ports: [{ name: 'http', port: 8080, targetPort: 'http' }],
    },
  },
  minifluxPostgresService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'miniflux-postgres',
      namespace: 'feeds',
      labels: dbLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: dbLabels,
      ports: [{ name: 'postgres', port: 5432, targetPort: 'postgres' }],
    },
  },
  minifluxDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'miniflux',
      namespace: 'feeds',
      labels: appLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: appLabels },
      template: {
        metadata: { labels: appLabels },
        spec: {
          containers: [{
            name: 'miniflux',
            image: 'miniflux/miniflux:2.3.3@sha256:4c24c30b8b420c77e3d074bfb6d78cfe5d37670f895fa68c09c43cb719b9ab04',
            ports: [{ name: 'http', containerPort: 8080 }],
            env: [
              { name: 'DATABASE_URL', valueFrom: { secretKeyRef: { name: 'miniflux-env', key: 'DATABASE_URL' } } },
              { name: 'RUN_MIGRATIONS', value: '1' },
              { name: 'CREATE_ADMIN', value: '1' },
              { name: 'ADMIN_USERNAME', value: 'admin' },
              { name: 'ADMIN_PASSWORD', valueFrom: { secretKeyRef: { name: 'miniflux-env', key: 'ADMIN_PASSWORD' } } },
              { name: 'BASE_URL', value: 'http://miniflux.localhost:17480' },
            ],
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              runAsUser: 65534,
              runAsGroup: 65534,
              capabilities: { drop: ['ALL'] },
            },
            startupProbe: {
              httpGet: { path: '/healthcheck', port: 'http' },
              periodSeconds: 2,
              failureThreshold: 30,
            },
            readinessProbe: {
              httpGet: { path: '/readyz', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            livenessProbe: {
              httpGet: { path: '/healthz', port: 'http' },
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '25m', memory: '128Mi' },
              limits: { cpu: '500m', memory: '512Mi' },
            },
          }],
        },
      },
    },
  },
  minifluxPostgres: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'miniflux-postgres',
      namespace: 'feeds',
      labels: dbLabels,
    },
    spec: {
      serviceName: 'miniflux-postgres',
      replicas: 1,
      selector: { matchLabels: dbLabels },
      template: {
        metadata: { labels: dbLabels },
        spec: {
          securityContext: { fsGroup: 70 },
          containers: [{
            name: 'postgres',
            image: 'postgres:18-alpine@sha256:b6a16ed0eb96e2c362811f7eeb951eac8b459e7b40be4149ea5444aa7c65569b',
            ports: [{ name: 'postgres', containerPort: 5432 }],
            env: [
              { name: 'POSTGRES_USER', value: 'miniflux' },
              { name: 'POSTGRES_PASSWORD', valueFrom: { secretKeyRef: { name: 'miniflux-env', key: 'POSTGRES_PASSWORD' } } },
              { name: 'POSTGRES_DB', value: 'miniflux' },
              { name: 'PGDATA', value: '/var/lib/postgresql/data/pgdata' },
            ],
            readinessProbe: {
              exec: { command: ['pg_isready', '-U', 'miniflux', '-d', 'miniflux'] },
              initialDelaySeconds: 10,
              periodSeconds: 5,
              timeoutSeconds: 5,
              failureThreshold: 12,
            },
            resources: {
              requests: { cpu: '50m', memory: '256Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            volumeMounts: [{ name: 'data', mountPath: '/var/lib/postgresql/data' }],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'miniflux-db' } }],
        },
      },
    },
  },
}
