local labels = {
  'app.kubernetes.io/name': 'meilisearch',
  'app.kubernetes.io/part-of': 'kosmos-meilisearch',
};

{
  deployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'meilisearch',
      namespace: 'meilisearch',
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
            runAsNonRoot: true,
            runAsUser: 1000,
            runAsGroup: 1000,
            fsGroup: 1000,
            fsGroupChangePolicy: 'OnRootMismatch',
            seccompProfile: { type: 'RuntimeDefault' },
          },
          containers: [{
            name: 'meilisearch',
            image: 'getmeili/meilisearch:v1.53.2@sha256:c94e58ca09662dd6e65e8f1b0fd145767be3da7d5422a863a27b8d2b68e090c9',
            ports: [{ name: 'http', containerPort: 7700 }],
            env: [
              { name: 'MEILI_ENV', value: 'production' },
              { name: 'MEILI_NO_ANALYTICS', value: 'true' },
              {
                name: 'MEILI_MASTER_KEY',
                valueFrom: {
                  secretKeyRef: {
                    name: 'meilisearch-master-key',
                    key: 'MEILI_MASTER_KEY',
                  },
                },
              },
            ],
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              capabilities: { drop: ['ALL'] },
            },
            startupProbe: {
              httpGet: { path: '/health', port: 'http' },
              periodSeconds: 2,
              failureThreshold: 60,
              timeoutSeconds: 1,
            },
            readinessProbe: {
              httpGet: { path: '/health', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            livenessProbe: {
              httpGet: { path: '/health', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '100m', memory: '512Mi' },
              limits: { cpu: '1', memory: '2Gi' },
            },
            volumeMounts: [{ name: 'data', mountPath: '/meili_data' }],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'meilisearch-data' } }],
        },
      },
    },
  },
  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'meilisearch',
      namespace: 'meilisearch',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 7700, targetPort: 'http' }],
    },
  },
}
