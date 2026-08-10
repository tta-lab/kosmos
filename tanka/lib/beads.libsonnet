local labels = {
  'app.kubernetes.io/name': 'beads',
  'app.kubernetes.io/part-of': 'kosmos-beads',
};
local serverConfig =
  'listener:\n' +
  '  host: 0.0.0.0\n' +
  '  port: 3306\n' +
  'system_variables:\n' +
  '  secure_file_priv: /var/lib/dolt/file-operations-disabled\n';

{
  beadsServerConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'beads-server-config',
      namespace: 'beads',
      labels: labels,
    },
    data: {
      'config.yaml': serverConfig,
    },
  },
  beadsService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'beads',
      namespace: 'beads',
      labels: labels,
    },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'mysql', port: 3307, targetPort: 'mysql' }],
    },
  },
  beadsStatefulSet: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'beads',
      namespace: 'beads',
      labels: labels,
    },
    spec: {
      serviceName: 'beads',
      replicas: 1,
      selector: { matchLabels: labels },
      template: {
        metadata: {
          labels: labels,
          annotations: {
            'kosmos.ttal/config-sha': std.md5(serverConfig),
          },
        },
        spec: {
          terminationGracePeriodSeconds: 30,
          containers: [{
            name: 'dolt',
            image: 'dolthub/dolt-sql-server:2.2.3@sha256:0243d2f3d1655a816d363885a7eb9e373f2aee9f96f8e289a0a0010f067314f3',
            env: [{ name: 'DOLT_ROOT_HOST', value: '%' }],
            ports: [{
              name: 'mysql',
              containerPort: 3306,
              hostPort: 3307,
              hostIP: '127.0.0.1',
            }],
            startupProbe: {
              tcpSocket: { port: 'mysql' },
              periodSeconds: 5,
              timeoutSeconds: 3,
              failureThreshold: 24,
            },
            readinessProbe: {
              exec: {
                command: [
                  '/bin/bash',
                  '-ec',
                  "dolt sql -q \"SELECT 1 FROM mysql.user WHERE User = 'root' AND Host = '%'\" | grep -q 1",
                ],
              },
              periodSeconds: 10,
              timeoutSeconds: 3,
              failureThreshold: 3,
            },
            livenessProbe: {
              tcpSocket: { port: 'mysql' },
              periodSeconds: 30,
              timeoutSeconds: 3,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '100m', memory: '256Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
              seccompProfile: { type: 'RuntimeDefault' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/var/lib/dolt' },
              {
                name: 'server-config',
                mountPath: '/etc/dolt/servercfg.d',
                readOnly: true,
              },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'beads-data' } },
            { name: 'server-config', configMap: { name: 'beads-server-config' } },
          ],
        },
      },
    },
  },
}
