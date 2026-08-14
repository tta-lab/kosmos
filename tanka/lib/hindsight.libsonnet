local labels = {
  'app.kubernetes.io/name': 'hindsight',
  'app.kubernetes.io/part-of': 'kosmos-hindsight',
};
local proxy = import 'proxy.libsonnet';

{
  hindsightService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'hindsight',
      namespace: 'hindsight',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [
        { name: 'api', port: 8888, targetPort: 'api' },
        { name: 'ui', port: 9999, targetPort: 'ui' },
      ],
    },
  },
  hindsightDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'hindsight',
      namespace: 'hindsight',
      labels: labels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          terminationGracePeriodSeconds: 120,
          securityContext: {
            fsGroup: 1000,
            fsGroupChangePolicy: 'OnRootMismatch',
          },
          containers: [{
            name: 'hindsight',
            image: 'ghcr.io/vectorize-io/hindsight:0.8.6@sha256:ffa391a77284e49f6b55e32c86f33529ac4257831407b14038a72b6a0a232039',
            ports: [
              {
                name: 'api',
                containerPort: 8888,
              },
              {
                name: 'ui',
                containerPort: 9999,
              },
            ],
            env: [
              { name: 'HINDSIGHT_API_LLM_PROVIDER', value: 'deepseek' },
              { name: 'HINDSIGHT_API_LLM_MODEL', value: 'deepseek-v4-flash' },
              { name: 'HINDSIGHT_API_WORKER_ID', value: 'hindsight' },
              { name: 'HTTP_PROXY', value: proxy.podUrl },
              { name: 'HTTPS_PROXY', value: proxy.podUrl },
              {
                name: 'NO_PROXY',
                value: proxy.clusterNoProxy(),
              },
              { name: 'HF_HUB_OFFLINE', value: '1' },
              { name: 'TRANSFORMERS_OFFLINE', value: '1' },
              {
                name: 'HINDSIGHT_API_LLM_API_KEY',
                valueFrom: {
                  secretKeyRef: {
                    name: 'hindsight-env',
                    key: 'HINDSIGHT_API_LLM_API_KEY',
                  },
                },
              },
            ],
            startupProbe: {
              httpGet: { path: '/health', port: 'api' },
              periodSeconds: 5,
              timeoutSeconds: 3,
              failureThreshold: 120,
            },
            readinessProbe: {
              httpGet: { path: '/health', port: 'api' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            livenessProbe: {
              httpGet: { path: '/health', port: 'api' },
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '500m', memory: '4Gi' },
              limits: { cpu: '8', memory: '8Gi' },
            },
            securityContext: {
              allowPrivilegeEscalation: false,
              runAsNonRoot: true,
              runAsUser: 1000,
              runAsGroup: 1000,
              capabilities: { drop: ['ALL'] },
              seccompProfile: { type: 'RuntimeDefault' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/home/hindsight/.pg0' },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'hindsight-data' } },
            { name: 'tmp', emptyDir: { sizeLimit: '1Gi' } },
          ],
        },
      },
    },
  },
}
