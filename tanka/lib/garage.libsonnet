local labels = {
  'app.kubernetes.io/name': 'garage',
  'app.kubernetes.io/part-of': 'kosmos-photos',
};
local corsLabels = {
  'app.kubernetes.io/name': 'garage-cors',
  'app.kubernetes.io/part-of': 'kosmos-photos',
};

{
  garageConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'garage',
      namespace: 'photos',
      labels: labels,
    },
    data: {
      'garage.toml': |||
        metadata_dir = "/var/lib/garage/meta"
        data_dir = "/var/lib/garage/data"
        metadata_snapshots_dir = "/var/lib/garage/snapshots"
        db_engine = "sqlite"
        replication_factor = 1
        metadata_fsync = true
        data_fsync = true
        metadata_auto_snapshot_interval = "24h"

        rpc_bind_addr = "[::]:3901"
        rpc_public_addr = "127.0.0.1:3901"

        [s3_api]
        s3_region = "garage"
        api_bind_addr = "[::]:3900"
        root_domain = ".s3.garage.localhost"
      |||,
    },
  },
  garageStatefulSet: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'garage',
      namespace: 'photos',
      labels: labels,
    },
    spec: {
      replicas: 1,
      serviceName: 'garage',
      selector: { matchLabels: labels },
      updateStrategy: { type: 'RollingUpdate' },
      template: {
        metadata: { labels: labels },
        spec: {
          containers: [{
            name: 'garage',
            image: 'dxflrs/garage:v2.3.0@sha256:866bd13ed2038ba7e7190e840482bc27234c4afaf77be8cfa439ae088c1e4690',
            command: ['/garage'],
            args: ['server', '--single-node', '--default-bucket'],
            env: [
              { name: 'GARAGE_CONFIG_FILE', value: '/etc/garage.toml' },
              {
                name: 'GARAGE_RPC_SECRET',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_RPC_SECRET' } },
              },
              {
                name: 'GARAGE_DEFAULT_ACCESS_KEY',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_ACCESS_KEY' } },
              },
              {
                name: 'GARAGE_DEFAULT_SECRET_KEY',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_SECRET_KEY' } },
              },
              { name: 'GARAGE_DEFAULT_BUCKET', value: 'b2-eu-cen' },
            ],
            ports: [
              { name: 's3', containerPort: 3900 },
              { name: 'rpc', containerPort: 3901 },
            ],
            startupProbe: {
              exec: { command: ['/garage', 'status'] },
              periodSeconds: 3,
              failureThreshold: 40,
            },
            readinessProbe: {
              exec: { command: ['/garage', 'status'] },
              periodSeconds: 10,
              timeoutSeconds: 5,
            },
            resources: {
              requests: { cpu: '50m', memory: '128Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            volumeMounts: [
              { name: 'config', mountPath: '/etc/garage.toml', subPath: 'garage.toml', readOnly: true },
              { name: 'data', mountPath: '/var/lib/garage' },
            ],
          }],
          volumes: [
            { name: 'config', configMap: { name: 'garage' } },
            { name: 'data', persistentVolumeClaim: { claimName: 'garage-data' } },
          ],
        },
      },
    },
  },
  garageService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'garage',
      namespace: 'photos',
      labels: labels,
    },
    spec: {
      selector: labels,
      ports: [
        { name: 's3', port: 3900, targetPort: 's3' },
        { name: 'rpc', port: 3901, targetPort: 'rpc' },
      ],
    },
  },
  garageCorsConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'garage-cors-v1',
      namespace: 'photos',
      labels: corsLabels,
    },
    data: {
      'cors.json': |||
        {
          "CORSRules": [{
            "AllowedHeaders": ["*"],
            "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
            "AllowedOrigins": ["*"],
            "ExposeHeaders": ["ETag"]
          }]
        }
      |||,
    },
  },
  garageCorsJob: {
    apiVersion: 'batch/v1',
    kind: 'Job',
    metadata: {
      name: 'garage-cors-v1',
      namespace: 'photos',
      labels: corsLabels,
    },
    spec: {
      activeDeadlineSeconds: 300,
      backoffLimit: 6,
      template: {
        metadata: { labels: corsLabels },
        spec: {
          restartPolicy: 'OnFailure',
          containers: [{
            name: 'apply',
            image: 'amazon/aws-cli:2.36.7@sha256:5b76c069e37cfa091ec6398dc683c09e0c9ef8ae2e557b0a36d931df34011227',
            command: ['/bin/sh', '-ec'],
            args: [|||
              until aws --endpoint-url http://garage:3900 s3api head-bucket --bucket b2-eu-cen >/dev/null 2>&1; do
                sleep 2
              done
              aws --endpoint-url http://garage:3900 s3api put-bucket-cors \
                --bucket b2-eu-cen \
                --cors-configuration file:///config/cors.json
            |||],
            env: [
              {
                name: 'AWS_ACCESS_KEY_ID',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_ACCESS_KEY' } },
              },
              {
                name: 'AWS_SECRET_ACCESS_KEY',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_SECRET_KEY' } },
              },
              { name: 'AWS_DEFAULT_REGION', value: 'garage' },
              { name: 'AWS_EC2_METADATA_DISABLED', value: 'true' },
              { name: 'AWS_PAGER', value: '' },
            ],
            resources: {
              requests: { cpu: '10m', memory: '32Mi' },
              limits: { cpu: '250m', memory: '256Mi' },
            },
            volumeMounts: [{ name: 'config', mountPath: '/config', readOnly: true }],
          }],
          volumes: [{ name: 'config', configMap: { name: 'garage-cors-v1' } }],
        },
      },
    },
  },
}
