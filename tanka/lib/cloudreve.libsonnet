local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-cloudreve',
};

local appLabels = labels('cloudreve');
local postgresLabels = labels('cloudreve-postgres');
local redisLabels = labels('cloudreve-redis');
local postgresImage = 'postgres:17-alpine@sha256:18cfe3ef5e6815560c98237d6216d1e5119702fb0f3894c8785dd58b8bbe5d73';

{
  cloudreveService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'cloudreve',
      namespace: 'cloudreve',
      labels: appLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: appLabels,
      ports: [{ name: 'http', port: 5212, targetPort: 'http' }],
    },
  },
  cloudrevePostgresService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'cloudreve-postgres',
      namespace: 'cloudreve',
      labels: postgresLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: postgresLabels,
      ports: [{ name: 'postgres', port: 5432, targetPort: 'postgres' }],
    },
  },
  cloudreveRedisService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'cloudreve-redis',
      namespace: 'cloudreve',
      labels: redisLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: redisLabels,
      ports: [{ name: 'redis', port: 6379, targetPort: 'redis' }],
    },
  },
  cloudreveDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'cloudreve',
      namespace: 'cloudreve',
      labels: appLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: appLabels },
      template: {
        metadata: { labels: appLabels },
        spec: {
          initContainers: [{
            name: 'wait-for-postgres',
            image: postgresImage,
            command: [
              'sh',
              '-ec',
              'until pg_isready --host=cloudreve-postgres --username=cloudreve --dbname=cloudreve >/dev/null 2>&1; do sleep 2; done',
            ],
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
            },
          }],
          containers: [{
            name: 'cloudreve',
            image: 'cloudreve/cloudreve:4.18.0@sha256:f7a464100bf6325e9ba58cb2b0ee60f9a24c58fc2eb90647720bc4b8f3cddd9a',
            ports: [{ name: 'http', containerPort: 5212 }],
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
            },
            startupProbe: {
              tcpSocket: { port: 'http' },
              periodSeconds: 2,
              failureThreshold: 60,
            },
            readinessProbe: {
              httpGet: { path: '/api/v4/site/ping', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 6,
            },
            livenessProbe: {
              httpGet: { path: '/api/v4/site/ping', port: 'http' },
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '250m', memory: '512Mi' },
              limits: { cpu: '2', memory: '2Gi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/cloudreve/data' },
              {
                name: 'config',
                mountPath: '/cloudreve/data/conf.ini',
                subPath: 'conf.ini',
                readOnly: true,
              },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'cloudreve-data' } },
            {
              name: 'config',
              secret: {
                secretName: 'cloudreve-env',
                items: [{ key: 'conf.ini', path: 'conf.ini' }],
              },
            },
          ],
        },
      },
    },
  },
  cloudrevePostgres: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'cloudreve-postgres',
      namespace: 'cloudreve',
      labels: postgresLabels,
    },
    spec: {
      serviceName: 'cloudreve-postgres',
      replicas: 1,
      selector: { matchLabels: postgresLabels },
      template: {
        metadata: { labels: postgresLabels },
        spec: {
          securityContext: { fsGroup: 70 },
          containers: [{
            name: 'postgres',
            image: postgresImage,
            ports: [{ name: 'postgres', containerPort: 5432 }],
            env: [
              { name: 'POSTGRES_USER', value: 'cloudreve' },
              { name: 'POSTGRES_PASSWORD', valueFrom: { secretKeyRef: { name: 'cloudreve-env', key: 'POSTGRES_PASSWORD' } } },
              { name: 'POSTGRES_DB', value: 'cloudreve' },
              { name: 'PGDATA', value: '/var/lib/postgresql/data/pgdata' },
            ],
            readinessProbe: {
              exec: { command: ['pg_isready', '-U', 'cloudreve', '-d', 'cloudreve'] },
              initialDelaySeconds: 10,
              periodSeconds: 5,
              timeoutSeconds: 5,
              failureThreshold: 12,
            },
            resources: {
              requests: { cpu: '50m', memory: '256Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            volumeMounts: [{ name: 'data', mountPath: '/var/lib/postgresql/data' }],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'cloudreve-postgres' } }],
        },
      },
    },
  },
  cloudreveRedis: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'cloudreve-redis',
      namespace: 'cloudreve',
      labels: redisLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: redisLabels },
      template: {
        metadata: { labels: redisLabels },
        spec: {
          containers: [{
            name: 'redis',
            image: 'redis:8-alpine@sha256:becdda6c7f4b3fb42e42fd7f120bbf5c54c4caaaf16f26da24e4563d2c1f0576',
            command: ['redis-server', '--save', '', '--appendonly', 'no'],
            ports: [{ name: 'redis', containerPort: 6379 }],
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
            },
            readinessProbe: {
              exec: { command: ['redis-cli', 'ping'] },
              initialDelaySeconds: 2,
              periodSeconds: 5,
              timeoutSeconds: 3,
              failureThreshold: 6,
            },
            resources: {
              requests: { cpu: '25m', memory: '64Mi' },
              limits: { cpu: '250m', memory: '256Mi' },
            },
          }],
        },
      },
    },
  },
}
