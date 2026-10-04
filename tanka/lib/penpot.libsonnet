local ingress = import 'ingress.libsonnet';
local labels(name) = {
  'app.kubernetes.io/name': 'penpot-' + name,
  'app.kubernetes.io/part-of': 'kosmos-penpot',
};
local env(name, value) = { name: name, value: value };
local secret(name, key) = {
  name: name,
  valueFrom: { secretKeyRef: { name: 'penpot-credentials', key: key } },
};
local publicUri = env('PENPOT_PUBLIC_URI', 'http://penpot.localhost:17480');
local flags = env('PENPOT_FLAGS', 'disable-email-verification disable-secure-session-cookies enable-mcp enable-admin-console');
local masterKey = secret('PENPOT_SECRET_KEY', 'PENPOT_SECRET_KEY');
local database = [
  env('PENPOT_DATABASE_URI', 'postgresql://penpot-postgres:5432/penpot'),
  env('PENPOT_DATABASE_USERNAME', 'penpot'),
  secret('PENPOT_DATABASE_PASSWORD', 'POSTGRES_PASSWORD'),
];
local redis = env('PENPOT_REDIS_URI', 'redis://penpot-valkey:6379/0');
local internalUri = env('PENPOT_INTERNAL_URI', 'http://penpot-frontend.penpot.svc.cluster.local:8080');
local adminUri = env('PENPOT_ADMIN_CONSOLE_URI', 'http://penpot-admin-console.penpot.svc.cluster.local:3000');
local bodySize = env('PENPOT_HTTP_SERVER_MAX_BODY_SIZE', '367001600');
local assetsMount = { name: 'assets', mountPath: '/opt/data/assets' };
local assetsVolume = { name: 'assets', persistentVolumeClaim: { claimName: 'penpot-assets' } };
local tcpProbe(port) = { tcpSocket: { port: port } };
local workload(name, container, volumes=[]) = {
  [name + 'Deployment']: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: { name: 'penpot-' + name, namespace: 'penpot', labels: labels(name) },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels(name) },
      template: {
        metadata: { labels: labels(name) },
        spec: {
          automountServiceAccountToken: false,
          securityContext: { runAsUser: 1001, runAsGroup: 1001, seccompProfile: { type: 'RuntimeDefault' } },
          containers: [{
            name: name,
            securityContext: {
              allowPrivilegeEscalation: false,
              runAsNonRoot: true,
              capabilities: { drop: ['ALL'] },
            },
            startupProbe: tcpProbe(container.ports[0].name) + { periodSeconds: 5, timeoutSeconds: 5, failureThreshold: 120 },
            readinessProbe: tcpProbe(container.ports[0].name) + { periodSeconds: 10, timeoutSeconds: 5 },
          } + container],
          volumes: volumes,
        },
      },
    },
  },
  [name + 'Service']: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: { name: 'penpot-' + name, namespace: 'penpot', labels: labels(name) },
    spec: {
      type: 'ClusterIP',
      selector: labels(name),
      ports: [{ name: p.name, port: p.containerPort, targetPort: p.name } for p in container.ports],
    },
  },
};

workload('frontend', {
  image: 'penpotapp/frontend:2.18.1@sha256:e1eb4756ec175eb71390f9bf0ddee819468d72f67f12cf3b1532bee8d591217e',
  ports: [{ name: 'http', containerPort: 8080 }],
  env: [
    publicUri,
    flags,
    bodySize,
    adminUri,
    env('PENPOT_BACKEND_URI', 'http://penpot-backend.penpot.svc.cluster.local:6060'),
    env('PENPOT_EXPORTER_URI', 'http://penpot-exporter.penpot.svc.cluster.local:6061'),
    env('PENPOT_MCP_URI', 'http://penpot-mcp.penpot.svc.cluster.local:4401'),
    env('PENPOT_MCP_URI_WS', 'http://penpot-mcp.penpot.svc.cluster.local:4402'),
    env('PENPOT_DISABLE_IPV6_LISTEN', 'true'),
  ],
  startupProbe: { httpGet: { path: '/readyz', port: 'http' }, periodSeconds: 5, timeoutSeconds: 5, failureThreshold: 120 },
  readinessProbe: { httpGet: { path: '/readyz', port: 'http' }, periodSeconds: 10, timeoutSeconds: 5 },
  resources: { requests: { cpu: '50m', memory: '128Mi' }, limits: { cpu: '1', memory: '1Gi' } },
  volumeMounts: [assetsMount { readOnly: true }],
}, [assetsVolume]) +
workload('backend', {
  image: 'penpotapp/backend:2.18.1@sha256:3b7df71db88d7c478b6a10103acb4108fa86a17a47277de81437de3899959e9e',
  ports: [{ name: 'http', containerPort: 6060 }],
  env: [
    publicUri,
    flags,
    bodySize,
    masterKey,
    redis,
    adminUri,
    env('PENPOT_OBJECTS_STORAGE_BACKEND', 'fs'),
    env('PENPOT_OBJECTS_STORAGE_FS_DIRECTORY', '/opt/data/assets'),
    env('PENPOT_TELEMETRY_ENABLED', 'false'),
    env('JAVA_TOOL_OPTIONS', '-Xmx1536m'),
  ] + database,
  startupProbe: { httpGet: { path: '/readyz', port: 'http' }, periodSeconds: 5, timeoutSeconds: 5, failureThreshold: 120 },
  readinessProbe: { httpGet: { path: '/readyz', port: 'http' }, periodSeconds: 10, timeoutSeconds: 5 },
  resources: { requests: { cpu: '250m', memory: '1Gi' }, limits: { cpu: '2', memory: '2Gi' } },
  volumeMounts: [assetsMount],
}, [assetsVolume]) +
workload('exporter', {
  image: 'penpotapp/exporter:2.18.1@sha256:3b6f9d808c777908e4f4e290e91458ec747678a7994e39125e4f3af4ef70ba9f',
  ports: [{ name: 'http', containerPort: 6061 }],
  env: [publicUri, masterKey, redis, internalUri],
  resources: { requests: { cpu: '100m', memory: '256Mi' }, limits: { cpu: '2', memory: '1Gi' } },
  volumeMounts: [{ name: 'shm', mountPath: '/dev/shm' }],
}, [{ name: 'shm', emptyDir: { medium: 'Memory', sizeLimit: '256Mi' } }]) +
workload('admin-console', {
  securityContext: { runAsUser: 65532, runAsGroup: 65532, runAsNonRoot: true, allowPrivilegeEscalation: false, capabilities: { drop: ['ALL'] } },
  image: 'penpotapp/admin-console:2.18.1@sha256:5935b5adbf33eb7abaabfab657fe8f5d465cac08e62e340f932ddb35ce0f311f',
  ports: [{ name: 'http', containerPort: 3000 }],
  env: [publicUri, masterKey, internalUri] + database,
  resources: { requests: { cpu: '50m', memory: '128Mi' }, limits: { cpu: '1', memory: '512Mi' } },
}) +
workload('mcp', {
  image: 'penpotapp/mcp:2.18.1@sha256:710505af665da0e37bd6c0d420100b62ce8a712f6050f01c3670ab11bc663e96',
  ports: [{ name: 'http', containerPort: 4401 }, { name: 'ws', containerPort: 4402 }],
  env: [env('PENPOT_MCP_SERVER_HOST', '0.0.0.0'), env('PENPOT_MCP_REMOTE_MODE', 'true')],
  securityContext: { runAsUser: 1000, runAsGroup: 1000, runAsNonRoot: true, allowPrivilegeEscalation: false, capabilities: { drop: ['ALL'] } },
  resources: { requests: { cpu: '50m', memory: '128Mi' }, limits: { cpu: '1', memory: '512Mi' } },
}) +
workload('postgres', {
  image: 'postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51',
  ports: [{ name: 'postgres', containerPort: 5432 }],
  env: [
    env('POSTGRES_DB', 'penpot'),
    env('POSTGRES_USER', 'penpot'),
    env('POSTGRES_INITDB_ARGS', '--data-checksums'),
    env('PGDATA', '/var/lib/postgresql/data/pgdata'),
    secret('POSTGRES_PASSWORD', 'POSTGRES_PASSWORD'),
  ],
  securityContext: {
    runAsUser: 999,
    runAsGroup: 999,
    runAsNonRoot: true,
    allowPrivilegeEscalation: false,
    capabilities: { drop: ['ALL'] },
  },
  startupProbe: { exec: { command: ['pg_isready', '-q', '-U', 'penpot', '-d', 'penpot'] }, periodSeconds: 5, timeoutSeconds: 5, failureThreshold: 60 },
  readinessProbe: { exec: { command: ['pg_isready', '-q', '-U', 'penpot', '-d', 'penpot'] }, periodSeconds: 10, timeoutSeconds: 5 },
  resources: { requests: { cpu: '100m', memory: '256Mi' }, limits: { cpu: '1', memory: '1Gi' } },
  volumeMounts: [{ name: 'data', mountPath: '/var/lib/postgresql/data' }],
}, [{ name: 'data', persistentVolumeClaim: { claimName: 'penpot-postgres-data' } }]) +
workload('valkey', {
  image: 'valkey/valkey:8.1@sha256:640c5e62cea04b6d6f2084232651d0cc70362d31f4f805e7be94dbed6855e8f2',
  ports: [{ name: 'redis', containerPort: 6379 }],
  args: ['valkey-server', '--maxmemory', '128mb', '--maxmemory-policy', 'volatile-lfu', '--save', '', '--appendonly', 'no'],
  securityContext: {
    runAsUser: 999,
    runAsGroup: 999,
    runAsNonRoot: true,
    allowPrivilegeEscalation: false,
    capabilities: { drop: ['ALL'] },
  },
  readinessProbe: { exec: { command: ['valkey-cli', 'ping'] }, periodSeconds: 10, timeoutSeconds: 5 },
  resources: { requests: { cpu: '20m', memory: '64Mi' }, limits: { cpu: '500m', memory: '256Mi' } },
}) + { penpotIngress: ingress('penpot') }
