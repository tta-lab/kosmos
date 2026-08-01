local labels = {
  'app.kubernetes.io/name': 'memos',
  'app.kubernetes.io/part-of': 'kosmos-notes',
};

{
  memosService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'memos',
      namespace: 'notes',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 5230, targetPort: 'http' }],
    },
  },
  memosDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'memos',
      namespace: 'notes',
      labels: labels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          securityContext: {
            fsGroup: 10001,
            fsGroupChangePolicy: 'OnRootMismatch',
          },
          containers: [{
            name: 'memos',
            image: 'neosmemo/memos:0.29.1@sha256:3e1253477066eb2aefa91145f7f9038bb931ed88c8a3ee05310a933594cdba7d',
            ports: [{ name: 'http', containerPort: 5230 }],
            env: [
              { name: 'MEMOS_ADDR', value: '0.0.0.0' },
              { name: 'MEMOS_PORT', value: '5230' },
              { name: 'MEMOS_DATA', value: '/var/opt/memos' },
              { name: 'MEMOS_DRIVER', value: 'sqlite' },
              { name: 'MEMOS_INSTANCE_URL', value: 'http://memos.localhost:17480' },
            ],
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              runAsUser: 10001,
              runAsGroup: 10001,
              capabilities: { drop: ['ALL'] },
            },
            startupProbe: {
              httpGet: { path: '/healthz', port: 'http' },
              periodSeconds: 2,
              failureThreshold: 30,
            },
            readinessProbe: {
              httpGet: { path: '/healthz', port: 'http' },
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
              requests: { cpu: '25m', memory: '64Mi' },
              limits: { cpu: '500m', memory: '512Mi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/var/opt/memos' },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'memos-data' } },
            { name: 'tmp', emptyDir: { medium: 'Memory', sizeLimit: '64Mi' } },
          ],
        },
      },
    },
  },
}
