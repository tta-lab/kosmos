local labels = {
  'app.kubernetes.io/name': 'codex-bridge',
  'app.kubernetes.io/part-of': 'kosmos-codex-bridge',
};
local proxy = import 'proxy.libsonnet';

local bridgeImage = 'ghcr.io/lamplitisles/kepos-codex-bridge:sha-af4a97e7203e064a645d971230c83676e90581e9@sha256:7c0edd8483162d541234de25a980dfce0d8320368a483f160a1fa36469b1cc37';
local relayImage = 'docker.io/alpine/socat:1.8.0.3@sha256:beb4a68d9e4fe6b0f21ea774a0fde6c31f580dde6368939ed70100c5385b015e';

{
  codexBridgeService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'codex-bridge',
      namespace: 'codex-bridge',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 8787, targetPort: 'proxy' }],
    },
  },
  codexBridgeDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'codex-bridge',
      namespace: 'codex-bridge',
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
          terminationGracePeriodSeconds: 30,
          containers: [
            {
              name: 'bridge',
              image: bridgeImage,
              imagePullPolicy: 'IfNotPresent',
              args: [
                'serve',
                '--auth-file',
                '/home/neil/.codex/auth.json',
                '--port',
                '8787',
              ],
              env: [
                { name: 'HTTP_PROXY', value: proxy.podUrl },
                { name: 'HTTPS_PROXY', value: proxy.podUrl },
                { name: 'NO_PROXY', value: proxy.clusterNoProxy() },
              ],
              resources: {
                requests: { cpu: '20m', memory: '32Mi' },
                limits: { cpu: '1', memory: '256Mi' },
              },
              securityContext: {
                allowPrivilegeEscalation: false,
                readOnlyRootFilesystem: true,
                runAsNonRoot: true,
                runAsUser: 1000,
                runAsGroup: 100,
                capabilities: { drop: ['ALL'] },
                seccompProfile: { type: 'RuntimeDefault' },
              },
              volumeMounts: [
                { name: 'codex-home', mountPath: '/home/neil/.codex' },
                { name: 'tmp', mountPath: '/tmp' },
              ],
            },
            {
              name: 'loopback-relay',
              image: relayImage,
              args: [
                '-d',
                '-d',
                'TCP-LISTEN:8788,fork,reuseaddr',
                'TCP:127.0.0.1:8787',
              ],
              ports: [{ name: 'proxy', containerPort: 8788 }],
              startupProbe: {
                exec: {
                  command: [
                    '/usr/bin/socat',
                    '-u',
                    'OPEN:/dev/null',
                    'TCP:127.0.0.1:8787,connect-timeout=2',
                  ],
                },
                periodSeconds: 2,
                timeoutSeconds: 3,
                failureThreshold: 60,
              },
              readinessProbe: {
                exec: {
                  command: [
                    '/usr/bin/socat',
                    '-u',
                    'OPEN:/dev/null',
                    'TCP:127.0.0.1:8787,connect-timeout=2',
                  ],
                },
                periodSeconds: 5,
                timeoutSeconds: 3,
                failureThreshold: 3,
              },
              livenessProbe: {
                exec: {
                  command: [
                    '/usr/bin/socat',
                    '-u',
                    'OPEN:/dev/null',
                    'TCP:127.0.0.1:8787,connect-timeout=2',
                  ],
                },
                periodSeconds: 30,
                timeoutSeconds: 3,
                failureThreshold: 3,
              },
              resources: {
                requests: { cpu: '5m', memory: '8Mi' },
                limits: { cpu: '100m', memory: '32Mi' },
              },
              securityContext: {
                allowPrivilegeEscalation: false,
                readOnlyRootFilesystem: true,
                runAsNonRoot: true,
                runAsUser: 10002,
                runAsGroup: 10002,
                capabilities: { drop: ['ALL'] },
                seccompProfile: { type: 'RuntimeDefault' },
              },
            },
          ],
          volumes: [
            {
              name: 'codex-home',
              hostPath: {
                path: '/home/neil/.codex',
                type: 'Directory',
              },
            },
            { name: 'tmp', emptyDir: { sizeLimit: '64Mi' } },
          ],
        },
      },
    },
  },
}
