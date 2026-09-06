local storage = import 'impri-storage.libsonnet';

local serverLabels = {
  'app.kubernetes.io/name': 'impri-server',
  'app.kubernetes.io/part-of': 'kosmos-impri',
};
local uiLabels = {
  'app.kubernetes.io/name': 'impri-ui',
  'app.kubernetes.io/part-of': 'kosmos-impri',
};
local imageRevision = 'edc8147e';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: { name: 'impri' },
  },
  serverService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'server',
      namespace: 'impri',
      labels: serverLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: serverLabels,
      ports: [{ name: 'http', port: 8484, targetPort: 'http' }],
    },
  },
  serverDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'impri-server',
      namespace: 'impri',
      labels: serverLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: serverLabels },
      template: {
        metadata: { labels: serverLabels },
        spec: {
          automountServiceAccountToken: false,
          securityContext: {
            fsGroup: 10001,
            fsGroupChangePolicy: 'OnRootMismatch',
          },
          containers: [{
            name: 'server',
            image: 'localhost/kosmos/impri-server:' + imageRevision,
            imagePullPolicy: 'Never',
            ports: [{ name: 'http', containerPort: 8484 }],
            env: [
              { name: 'DB_PATH', value: '/app/data/impri.db' },
              { name: 'HOST', value: '0.0.0.0' },
              { name: 'PORT', value: '8484' },
              { name: 'BASE_URL', value: 'http://impri.localhost:17480' },
              { name: 'DISABLE_WATCHER_SCHEDULER', value: '1' },
              {
                name: 'WEBHOOK_SECRET',
                valueFrom: {
                  secretKeyRef: {
                    name: 'impri-runtime',
                    key: 'WEBHOOK_SECRET',
                  },
                },
              },
            ],
            startupProbe: {
              httpGet: { path: '/readyz', port: 'http' },
              periodSeconds: 2,
              timeoutSeconds: 2,
              failureThreshold: 60,
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
              requests: { cpu: '50m', memory: '128Mi' },
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
              { name: 'data', mountPath: '/app/data' },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'impri-data' } },
            { name: 'tmp', emptyDir: { medium: 'Memory', sizeLimit: '64Mi' } },
          ],
        },
      },
    },
  },
  uiService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'impri-ui',
      namespace: 'impri',
      labels: uiLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: uiLabels,
      ports: [{ name: 'http', port: 8080, targetPort: 'http' }],
    },
  },
  uiDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'impri-ui',
      namespace: 'impri',
      labels: uiLabels,
    },
    spec: {
      replicas: 1,
      selector: { matchLabels: uiLabels },
      template: {
        metadata: { labels: uiLabels },
        spec: {
          automountServiceAccountToken: false,
          containers: [{
            name: 'ui',
            image: 'localhost/kosmos/impri-ui:' + imageRevision,
            imagePullPolicy: 'Never',
            command: ['nginx'],
            args: ['-g', 'daemon off;'],
            ports: [{ name: 'http', containerPort: 8080 }],
            startupProbe: {
              httpGet: { path: '/healthz', port: 'http' },
              periodSeconds: 2,
              timeoutSeconds: 2,
              failureThreshold: 60,
            },
            readinessProbe: {
              httpGet: { path: '/healthz', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            livenessProbe: {
              httpGet: { path: '/', port: 'http' },
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '20m', memory: '32Mi' },
              limits: { cpu: '250m', memory: '128Mi' },
            },
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              runAsUser: 101,
              runAsGroup: 101,
              capabilities: { drop: ['ALL'] },
              seccompProfile: { type: 'RuntimeDefault' },
            },
            volumeMounts: [
              { name: 'cache', mountPath: '/var/cache/nginx' },
              { name: 'run', mountPath: '/var/run' },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'cache', emptyDir: { sizeLimit: '64Mi' } },
            { name: 'run', emptyDir: { medium: 'Memory', sizeLimit: '8Mi' } },
            { name: 'tmp', emptyDir: { medium: 'Memory', sizeLimit: '16Mi' } },
          ],
        },
      },
    },
  },
} + storage
