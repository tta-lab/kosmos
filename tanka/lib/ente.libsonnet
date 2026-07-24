local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-photos',
};

local postgresLabels = labels('postgres');
local museumLabels = labels('museum');

{
  museumConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'museum',
      namespace: 'photos',
      labels: museumLabels,
    },
    data: {
      'museum.yaml': |||
        db:
            host: postgres
            port: 5432
            name: ente_db
            user: ente
            sslmode: disable

        s3:
            are_local_buckets: true
            use_path_style_urls: true
            b2-eu-cen:
                endpoint: ente-storage.localhost:17480
                region: garage
                bucket: b2-eu-cen

        replication:
            enabled: false
      |||,
    },
  },
  postgresStatefulSet: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'postgres',
      namespace: 'photos',
      labels: postgresLabels,
    },
    spec: {
      replicas: 1,
      serviceName: 'postgres',
      selector: { matchLabels: postgresLabels },
      updateStrategy: { type: 'RollingUpdate' },
      template: {
        metadata: { labels: postgresLabels },
        spec: {
          containers: [{
            name: 'postgres',
            image: 'postgres:15.18-bookworm@sha256:b0c5bab0fbba8e0c221f73b1dc6359ec35f8650074377e727299df248fc8ad51',
            env: [
              { name: 'POSTGRES_USER', value: 'ente' },
              { name: 'POSTGRES_DB', value: 'ente_db' },
              {
                name: 'POSTGRES_PASSWORD',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'POSTGRES_PASSWORD' } },
              },
              { name: 'PGDATA', value: '/var/lib/postgresql/data/pgdata' },
            ],
            ports: [{ name: 'postgres', containerPort: 5432 }],
            startupProbe: {
              exec: { command: ['pg_isready', '-q', '-U', 'ente', '-d', 'ente_db'] },
              periodSeconds: 3,
              failureThreshold: 40,
            },
            readinessProbe: {
              exec: { command: ['pg_isready', '-q', '-U', 'ente', '-d', 'ente_db'] },
              periodSeconds: 10,
            },
            resources: {
              requests: { cpu: '50m', memory: '256Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            volumeMounts: [{ name: 'data', mountPath: '/var/lib/postgresql/data' }],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'postgres-data' } }],
        },
      },
    },
  },
  postgresService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'postgres',
      namespace: 'photos',
      labels: postgresLabels,
    },
    spec: {
      selector: postgresLabels,
      ports: [{ name: 'postgres', port: 5432, targetPort: 'postgres' }],
    },
  },
  museumDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'museum',
      namespace: 'photos',
      labels: museumLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: museumLabels },
      template: {
        metadata: { labels: museumLabels },
        spec: {
          containers: [{
            name: 'museum',
            image: 'ghcr.io/ente/server:0137a0c754ac0fe4f2c4c7421727c349327eb990@sha256:e9e06eb01834c38f41a3a09f9a64885b631346ce0005ccff2153faea403bd6e2',
            env: [
              {
                name: 'ENTE_DB_PASSWORD',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'POSTGRES_PASSWORD' } },
              },
              {
                name: 'ENTE_KEY_ENCRYPTION',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'ENTE_KEY_ENCRYPTION' } },
              },
              {
                name: 'ENTE_KEY_HASH',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'ENTE_KEY_HASH' } },
              },
              {
                name: 'ENTE_JWT_SECRET',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'ENTE_JWT_SECRET' } },
              },
              {
                name: 'ENTE_S3_B2_EU_CEN_KEY',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_ACCESS_KEY' } },
              },
              {
                name: 'ENTE_S3_B2_EU_CEN_SECRET',
                valueFrom: { secretKeyRef: { name: 'ente-stack-env', key: 'GARAGE_SECRET_KEY' } },
              },
            ],
            ports: [{ name: 'http', containerPort: 8080 }],
            startupProbe: {
              httpGet: { path: '/ping', port: 'http' },
              periodSeconds: 3,
              failureThreshold: 40,
            },
            readinessProbe: {
              httpGet: { path: '/ping', port: 'http' },
              periodSeconds: 10,
            },
            resources: {
              requests: { cpu: '50m', memory: '128Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            volumeMounts: [{ name: 'config', mountPath: '/museum.yaml', subPath: 'museum.yaml', readOnly: true }],
          }],
          volumes: [{ name: 'config', configMap: { name: 'museum' } }],
        },
      },
    },
  },
  museumService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'museum',
      namespace: 'photos',
      labels: museumLabels,
    },
    spec: {
      selector: museumLabels,
      ports: [{ name: 'http', port: 8080, targetPort: 'http' }],
    },
  },
}
