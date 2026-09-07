local storage = import 'clipcascade-storage.libsonnet';

local labels = {
  'app.kubernetes.io/name': 'clipcascade',
  'app.kubernetes.io/part-of': 'kosmos-clipcascade',
};

local databaseSecretName = 'clipcascade-database';

local secretEnv(name, key) = {
  name: name,
  valueFrom: {
    secretKeyRef: {
      name: databaseSecretName,
      key: key,
    },
  },
};

local probes = {
  startupProbe: {
    httpGet: { path: '/health', port: 'http' },
    periodSeconds: 2,
    timeoutSeconds: 2,
    failureThreshold: 60,
  },
  readinessProbe: {
    httpGet: { path: '/health', port: 'http' },
    periodSeconds: 10,
    timeoutSeconds: 5,
    failureThreshold: 6,
  },
  livenessProbe: {
    httpGet: { path: '/health', port: 'http' },
    periodSeconds: 30,
    timeoutSeconds: 5,
    failureThreshold: 3,
  },
};

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: { name: 'clipcascade' },
  },
  clipcascadeService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'clipcascade',
      namespace: 'clipcascade',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 8080, targetPort: 'http' }],
    },
  },
  clipcascadeDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'clipcascade',
      namespace: 'clipcascade',
      labels: labels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          automountServiceAccountToken: false,
          securityContext: {
            fsGroup: 10001,
            fsGroupChangePolicy: 'OnRootMismatch',
          },
          containers: [{
            name: 'clipcascade',
            image: 'localhost/kosmos/clipcascade:faf6ac06',
            imagePullPolicy: 'Never',
            ports: [{ name: 'http', containerPort: 8080 }],
            env: [
              { name: 'CC_PORT', value: '8080' },
              { name: 'CC_P2P_ENABLED', value: 'false' },
              { name: 'CC_ALLOWED_ORIGINS', value: 'http://clipcascade.localhost:17480' },
              { name: 'CC_EXTERNAL_BROKER_ENABLED', value: 'false' },
              { name: 'CC_SERVER_DB_URL', value: 'jdbc:h2:file:/database/clipcascade;CIPHER=AES;MODE=PostgreSQL' },
              { name: 'CC_SERVER_DB_USERNAME', value: 'clipcascade' },
              secretEnv('CC_SERVER_DB_PASSWORD', 'CC_SERVER_DB_PASSWORD'),
            ],
          } + probes + {
            resources: {
              requests: { cpu: '100m', memory: '256Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              runAsUser: 10001,
              runAsGroup: 10001,
              capabilities: { drop: ['ALL'] },
              seccompProfile: { type: 'RuntimeDefault' },
            },
            volumeMounts: [
              { name: 'database', mountPath: '/database' },
              { name: 'logs', mountPath: '/app/logs' },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'database', persistentVolumeClaim: { claimName: 'clipcascade-data' } },
            { name: 'logs', emptyDir: { medium: 'Memory', sizeLimit: '64Mi' } },
            { name: 'tmp', emptyDir: { medium: 'Memory', sizeLimit: '64Mi' } },
          ],
        },
      },
    },
  },
} + storage
