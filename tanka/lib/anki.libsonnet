local labels = {
  'app.kubernetes.io/name': 'anki-sync-server',
  'app.kubernetes.io/part-of': 'kosmos-anki',
};

{
  ankiService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'anki-sync-server',
      namespace: 'anki',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 8080, targetPort: 'http' }],
    },
  },
  ankiDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'anki-sync-server',
      namespace: 'anki',
      labels: labels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          containers: [{
            name: 'anki-sync-server',
            image: 'jeankhawand/anki-sync-server:26.05@sha256:cbe79eb94aa8ffc718f324eccd76b9500736e33082b6fc27c563bc697169e059',
            env: [{
              name: 'SYNC_USER1',
              valueFrom: { secretKeyRef: { name: 'anki-sync-env', key: 'SYNC_USER1' } },
            }],
            ports: [{ name: 'http', containerPort: 8080 }],
            readinessProbe: {
              httpGet: { path: '/health', port: 'http' },
              initialDelaySeconds: 5,
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 6,
            },
            resources: {
              requests: { cpu: '25m', memory: '32Mi' },
              limits: { cpu: '500m', memory: '256Mi' },
            },
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: {
                drop: ['ALL'],
                add: ['CHOWN', 'DAC_OVERRIDE', 'FOWNER', 'SETGID', 'SETUID'],
              },
            },
            volumeMounts: [{ name: 'data', mountPath: '/anki_data' }],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'anki-data' } }],
        },
      },
    },
  },
}
