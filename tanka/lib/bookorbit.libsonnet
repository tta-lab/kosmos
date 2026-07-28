local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-ebooks-evaluation',
};

local appLabels = labels('bookorbit');
local dbLabels = labels('bookorbit-postgres');

{
  bookorbitService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'bookorbit',
      namespace: 'ebooks',
      labels: appLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: appLabels,
      ports: [{ name: 'http', port: 3000, targetPort: 'http' }],
    },
  },
  bookorbitDatabaseService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'bookorbit-postgres',
      namespace: 'ebooks',
      labels: dbLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: dbLabels,
      ports: [{ name: 'postgres', port: 5432, targetPort: 'postgres' }],
    },
  },
  bookorbitDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'bookorbit',
      namespace: 'ebooks',
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
            name: 'bookorbit',
            image: 'ghcr.io/bookorbit/bookorbit:2.3.0@sha256:62048532c82ad4cfe9b728707136f140516f0f35766c2dc97969f22ed67794ae',
            ports: [{ name: 'http', containerPort: 3000 }],
            env: [
              { name: 'NODE_ENV', value: 'production' },
              { name: 'PORT', value: '3000' },
              { name: 'POSTGRES_HOST', value: 'bookorbit-postgres' },
              { name: 'POSTGRES_PORT', value: '5432' },
              { name: 'POSTGRES_USER', value: 'bookorbit' },
              { name: 'POSTGRES_PASSWORD', valueFrom: { secretKeyRef: { name: 'bookorbit-env', key: 'POSTGRES_PASSWORD' } } },
              { name: 'POSTGRES_DB', value: 'bookorbit' },
              { name: 'JWT_SECRET', valueFrom: { secretKeyRef: { name: 'bookorbit-env', key: 'JWT_SECRET' } } },
              { name: 'SETUP_BOOTSTRAP_TOKEN', valueFrom: { secretKeyRef: { name: 'bookorbit-env', key: 'SETUP_BOOTSTRAP_TOKEN' } } },
              { name: 'APP_URL', value: 'http://bookorbit.localhost:17480' },
              { name: 'CLIENT_URL', value: 'http://bookorbit.localhost:17480' },
              { name: 'PUID', value: '1000' },
              { name: 'PGID', value: '1000' },
              { name: 'NODE_MAX_OLD_SPACE_SIZE', value: 'auto' },
            ],
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              capabilities: {
                drop: ['ALL'],
                add: ['CHOWN', 'DAC_OVERRIDE', 'FOWNER', 'SETGID', 'SETUID'],
              },
            },
            readinessProbe: {
              httpGet: { path: '/api/v1/health', port: 'http' },
              initialDelaySeconds: 20,
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 12,
            },
            resources: {
              requests: { cpu: '100m', memory: '512Mi' },
              limits: { cpu: '2', memory: '2Gi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/data', subPath: 'data' },
              { name: 'data', mountPath: '/books', subPath: 'books' },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'bookorbit-data' } },
            { name: 'tmp', emptyDir: { medium: 'Memory', sizeLimit: '256Mi' } },
          ],
        },
      },
    },
  },
  bookorbitDatabase: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'bookorbit-postgres',
      namespace: 'ebooks',
      labels: dbLabels,
    },
    spec: {
      serviceName: 'bookorbit-postgres',
      replicas: 1,
      selector: { matchLabels: dbLabels },
      template: {
        metadata: { labels: dbLabels },
        spec: {
          securityContext: { fsGroup: 999 },
          containers: [{
            name: 'postgres',
            image: 'pgvector/pgvector:pg18@sha256:12a379b47ad65289572ea0756efc11b7c241a6662833e8af7038cd3b73d647e0',
            ports: [{ name: 'postgres', containerPort: 5432 }],
            env: [
              { name: 'POSTGRES_USER', value: 'bookorbit' },
              { name: 'POSTGRES_PASSWORD', valueFrom: { secretKeyRef: { name: 'bookorbit-env', key: 'POSTGRES_PASSWORD' } } },
              { name: 'POSTGRES_DB', value: 'bookorbit' },
              { name: 'PGDATA', value: '/var/lib/postgresql/data/pgdata' },
            ],
            readinessProbe: {
              exec: { command: ['pg_isready', '-U', 'bookorbit', '-d', 'bookorbit'] },
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
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'bookorbit-db' } }],
        },
      },
    },
  },
}
