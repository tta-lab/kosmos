local labels = {
  'app.kubernetes.io/name': 'dagger',
  'app.kubernetes.io/part-of': 'kosmos-devops',
};

{
  daggerConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'dagger-engine',
      namespace: 'devops',
      labels: labels,
    },
    data: {
      'engine.json': |||
        {
          "gc": {
            "maxUsedSpace": "80%",
            "minFreeSpace": "20GB",
            "reservedSpace": "10GB",
            "sweepSize": "10GB"
          },
          "registries": {
            "docker.io": {
              "mirrors": ["mirror.gcr.io"]
            },
            "forgejo.localhost:17480": {
              "http": true
            }
          }
        }
      |||,
    },
  },
  daggerDaemonSet: {
    apiVersion: 'apps/v1',
    kind: 'DaemonSet',
    metadata: {
      name: 'dagger',
      namespace: 'devops',
      labels: labels,
    },
    spec: {
      selector: { matchLabels: labels },
      updateStrategy: { type: 'RollingUpdate', rollingUpdate: { maxUnavailable: 1 } },
      template: {
        metadata: { labels: labels },
        spec: {
          containers: [{
            name: 'engine',
            image: 'registry.dagger.io/engine:v0.21.7',
            env: [
              {
                name: 'NODE_IP',
                valueFrom: { fieldRef: { fieldPath: 'status.hostIP' } },
              },
              { name: 'HTTP_PROXY', value: 'http://$(NODE_IP):7890' },
              { name: 'HTTPS_PROXY', value: 'http://$(NODE_IP):7890' },
              {
                name: 'NO_PROXY',
                value: 'localhost,127.0.0.1,::1,10.42.0.0/16,10.43.0.0/16,10.89.0.0/16,10.90.0.0/16,.svc,.cluster.local,forgejo.localhost,woodpecker.localhost',
              },
            ],
            args: [
              '--config', '/etc/dagger/engine.json',
              '--network-name', 'dagger',
              '--network-cidr', '10.89.0.0/16',
              '--network-pool', '10.90.0.0/16',
              '--grpc-address', 'tcp://0.0.0.0:8080',
            ],
            securityContext: { privileged: true },
            ports: [{
              name: 'grpc',
              containerPort: 8080,
              hostPort: 8080,
              hostIP: '127.0.0.1',
            }],
            readinessProbe: {
              exec: { command: ['dagger', 'core', 'version'] },
              initialDelaySeconds: 5,
              periodSeconds: 10,
            },
            resources: {
              requests: { cpu: '1', memory: '1Gi' },
              limits: { cpu: '4', memory: '4Gi' },
            },
            volumeMounts: [
              { name: 'config', mountPath: '/etc/dagger/engine.json', subPath: 'engine.json', readOnly: true },
              { name: 'state', mountPath: '/var/lib/dagger' },
            ],
          }],
          volumes: [
            { name: 'config', configMap: { name: 'dagger-engine' } },
            { name: 'state', hostPath: { path: '/var/lib/kosmos-k3s/dagger', type: 'Directory' } },
          ],
        },
      },
    },
  },
  daggerService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'dagger',
      namespace: 'devops',
      labels: labels,
    },
    spec: {
      selector: labels,
      ports: [{ name: 'grpc', port: 8080, targetPort: 'grpc' }],
    },
  },
}
