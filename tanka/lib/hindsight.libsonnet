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
            image: 'ghcr.io/vectorize-io/hindsight:0.9.2@sha256:84ab276b8f501546deb6ea9c64a57291718b4e16a59dd9e02a02fdd5adfe9028',
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
              { name: 'HINDSIGHT_API_LLM_PROVIDER', value: 'openai-responses' },
              { name: 'HINDSIGHT_API_LLM_BASE_URL', value: 'http://codex-bridge.localhost:17480/hindsight' },
              { name: 'HINDSIGHT_API_LLM_MODEL', value: 'gpt-5.6-luna' },
              { name: 'HINDSIGHT_API_LLM_REASONING_EFFORT', value: 'xhigh' },
              { name: 'HINDSIGHT_API_LLM_API_KEY', value: 'bridge-managed-oauth' },
              { name: 'HINDSIGHT_API_RERANKER_PROVIDER', value: 'rrf' },
              { name: 'HINDSIGHT_API_WORKER_ID', value: 'hindsight' },
              { name: 'HTTP_PROXY', value: proxy.podUrl },
              { name: 'HTTPS_PROXY', value: proxy.podUrl },
              {
                name: 'NO_PROXY',
                value: proxy.clusterNoProxy(['.localhost']),
              },
              { name: 'HF_HUB_OFFLINE', value: '1' },
              { name: 'TRANSFORMERS_OFFLINE', value: '1' },
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
              { name: 'shm', mountPath: '/dev/shm' },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'hindsight-data' } },
            { name: 'tmp', emptyDir: { sizeLimit: '1Gi' } },
            { name: 'shm', emptyDir: { medium: 'Memory', sizeLimit: '1Gi' } },
          ],
        },
      },
    },
  },
}
