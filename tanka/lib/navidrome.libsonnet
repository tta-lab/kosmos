local labels = {
  'app.kubernetes.io/name': 'navidrome',
  'app.kubernetes.io/part-of': 'kosmos-navidrome',
};
local micronStorage = import './micron-storage.libsonnet';

{
  deployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'navidrome',
      namespace: 'navidrome',
      labels: labels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          initContainers: [micronStorage.waitForReady],
          containers: [{
            name: 'navidrome',
            image: 'deluan/navidrome:0.64.0@sha256:a384948b81bd1529986c5960169e7fc4fa00f46bde6bd517971a4c36671db2af',
            ports: [{ name: 'http', containerPort: 4533 }],
            env: [
              { name: 'ND_DATAFOLDER', value: '/data' },
              { name: 'ND_CACHEFOLDER', value: '/cache' },
              { name: 'ND_MUSICFOLDER', value: '/music' },
              { name: 'ND_ENFORCENONROOTUSER', value: 'true' },
              { name: 'ND_ENABLEDOWNLOADS', value: 'false' },
              { name: 'ND_ENABLESHARING', value: 'false' },
              { name: 'ND_ENABLEINSIGHTSCOLLECTOR', value: 'false' },
            ],
            securityContext: {
              allowPrivilegeEscalation: false,
              runAsUser: 1000,
              runAsGroup: 100,
              runAsNonRoot: true,
              capabilities: { drop: ['ALL'] },
              seccompProfile: { type: 'RuntimeDefault' },
            },
            startupProbe: {
              tcpSocket: { port: 'http' },
              periodSeconds: 3,
              failureThreshold: 40,
            },
            readinessProbe: {
              tcpSocket: { port: 'http' },
              periodSeconds: 10,
            },
            resources: {
              requests: { cpu: '50m', memory: '128Mi' },
              limits: { cpu: '500m', memory: '512Mi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/data' },
              { name: 'cache', mountPath: '/cache' },
              { name: 'music', mountPath: '/music', readOnly: true },
            ],
          }],
          volumes: [
            micronStorage.readyVolume,
            { name: 'data', persistentVolumeClaim: { claimName: 'navidrome-data' } },
            { name: 'cache', persistentVolumeClaim: { claimName: 'navidrome-cache' } },
            { name: 'music', persistentVolumeClaim: { claimName: 'navidrome-music' } },
          ],
        },
      },
    },
  },
  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'navidrome',
      namespace: 'navidrome',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 4533, targetPort: 'http' }],
    },
  },
}
