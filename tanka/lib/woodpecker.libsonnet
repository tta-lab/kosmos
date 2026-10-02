local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-devops',
};

local serverLabels = labels('woodpecker');
local agentLabels = labels('woodpecker-agent');
local postgresLabels = labels('woodpecker-postgres');
local postgresImage = 'postgres:18-alpine@sha256:b6a16ed0eb96e2c362811f7eeb951eac8b459e7b40be4149ea5444aa7c65569b';
local proxy = import 'proxy.libsonnet';

{
  woodpeckerServer: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'woodpecker',
      namespace: 'devops',
      labels: serverLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: serverLabels },
      template: {
        metadata: { labels: serverLabels },
        spec: {
          securityContext: {
            runAsUser: 1000,
            runAsGroup: 1000,
            fsGroup: 1000,
            fsGroupChangePolicy: 'OnRootMismatch',
          },
          containers: [{
            name: 'server',
            image: 'woodpeckerci/woodpecker-server:v3.18.0',
            envFrom: [{ secretRef: { name: 'woodpecker-server-env' } }],
            env: [
              { name: 'WOODPECKER_DATABASE_DRIVER', value: 'postgres' },
              {
                name: 'WOODPECKER_DATABASE_DATASOURCE',
                valueFrom: { secretKeyRef: { name: 'woodpecker-postgres-env', key: 'WOODPECKER_DATABASE_DATASOURCE' } },
              },
              { name: 'WOODPECKER_HOST', value: 'http://woodpecker.localhost:17480' },
              { name: 'WOODPECKER_SERVER_ADDR', value: ':8000' },
              { name: 'WOODPECKER_GRPC_ADDR', value: ':9000' },
              { name: 'WOODPECKER_FORGEJO', value: 'true' },
              { name: 'WOODPECKER_FORGEJO_URL', value: 'http://forgejo:3000' },
              { name: 'WOODPECKER_EXPERT_FORGE_OAUTH_HOST', value: 'http://forgejo.localhost:17480' },
              { name: 'WOODPECKER_EXPERT_WEBHOOK_HOST', value: 'http://woodpecker:8000' },
              { name: 'WOODPECKER_OPEN', value: 'false' },
              { name: 'WOODPECKER_ADMIN', value: 'neil' },
              {
                name: 'WOODPECKER_ENVIRONMENT',
                value:
                  '_EXPERIMENTAL_DAGGER_RUNNER_HOST:tcp://dagger:8080,GIT_CONFIG_COUNT:1,GIT_CONFIG_KEY_0:http.http://forgejo.localhost:17480.proxy,GIT_CONFIG_VALUE_0:http://canonical-gateway.devops.svc.cluster.local:17480,HTTPS_PROXY:'
                  + proxy.podUrl,
              },
            ],
            ports: [
              { name: 'http', containerPort: 8000 },
              { name: 'grpc', containerPort: 9000 },
            ],
            readinessProbe: {
              httpGet: { path: '/healthz', port: 'http' },
              initialDelaySeconds: 5,
              periodSeconds: 5,
            },
            resources: {
              requests: { cpu: '50m', memory: '128Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
          }],
        },
      },
    },
  },
  woodpeckerService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'woodpecker',
      namespace: 'devops',
      labels: serverLabels,
    },
    spec: {
      selector: serverLabels,
      ports: [
        { name: 'http', port: 8000, targetPort: 'http' },
        { name: 'grpc', port: 9000, targetPort: 'grpc' },
      ],
    },
  },
  woodpeckerPostgresService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'woodpecker-postgres',
      namespace: 'devops',
      labels: postgresLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: postgresLabels,
      ports: [{ name: 'postgres', port: 5432, targetPort: 'postgres' }],
    },
  },
  woodpeckerAgentServiceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'woodpecker-agent',
      namespace: 'devops',
      labels: agentLabels,
    },
  },
  woodpeckerAgentRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'Role',
    metadata: {
      name: 'woodpecker-agent',
      namespace: 'devops',
      labels: agentLabels,
    },
    rules: [
      { apiGroups: [''], resources: ['persistentvolumeclaims', 'services', 'secrets'], verbs: ['create', 'delete'] },
      { apiGroups: [''], resources: ['pods'], verbs: ['watch', 'create', 'delete', 'get', 'list'] },
      { apiGroups: [''], resources: ['pods/log'], verbs: ['get'] },
    ],
  },
  woodpeckerAgentRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'RoleBinding',
    metadata: {
      name: 'woodpecker-agent',
      namespace: 'devops',
      labels: agentLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'woodpecker-agent',
    },
    subjects: [{ kind: 'ServiceAccount', name: 'woodpecker-agent', namespace: 'devops' }],
  },
  woodpeckerAgent: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'woodpecker-agent',
      namespace: 'devops',
      labels: agentLabels,
    },
    spec: {
      replicas: 2,
      serviceName: 'woodpecker-agent',
      selector: { matchLabels: agentLabels },
      template: {
        metadata: { labels: agentLabels },
        spec: {
          serviceAccountName: 'woodpecker-agent',
          initContainers: [{
            name: 'wait-for-server',
            image: 'busybox:1.37.0',
            command: ['sh', '-c', 'until nc -z -w 2 woodpecker 9000; do sleep 2; done'],
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              runAsUser: 65534,
            },
            resources: {
              requests: { cpu: '1m', memory: '1Mi' },
              limits: { cpu: '10m', memory: '8Mi' },
            },
          }],
          containers: [{
            name: 'agent',
            image: 'woodpeckerci/woodpecker-agent:v3.18.0',
            env: [
              { name: 'WOODPECKER_SERVER', value: 'woodpecker:9000' },
              { name: 'WOODPECKER_BACKEND', value: 'kubernetes' },
              { name: 'WOODPECKER_BACKEND_K8S_NAMESPACE', value: 'devops' },
              { name: 'WOODPECKER_BACKEND_K8S_STORAGE_CLASS', value: 'local-path' },
              { name: 'WOODPECKER_BACKEND_K8S_STORAGE_RWX', value: 'false' },
              { name: 'WOODPECKER_BACKEND_K8S_VOLUME_SIZE', value: '10Gi' },
              { name: 'WOODPECKER_CONNECT_RETRY_COUNT', value: '1' },
              { name: 'WOODPECKER_HEALTHCHECK_ADDR', value: ':3000' },
              {
                name: 'WOODPECKER_AGENT_SECRET',
                valueFrom: { secretKeyRef: { name: 'woodpecker-server-env', key: 'WOODPECKER_AGENT_SECRET' } },
              },
            ],
            ports: [{ name: 'health', containerPort: 3000 }],
            readinessProbe: {
              httpGet: { path: '/healthz', port: 'health' },
              initialDelaySeconds: 3,
              periodSeconds: 5,
            },
            resources: {
              requests: { cpu: '50m', memory: '128Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
          }],
        },
      },
    },
  },
  woodpeckerPostgres: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'woodpecker-postgres',
      namespace: 'devops',
      labels: postgresLabels,
    },
    spec: {
      serviceName: 'woodpecker-postgres',
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
              { name: 'POSTGRES_USER', value: 'woodpecker' },
              { name: 'POSTGRES_DB', value: 'woodpecker' },
              {
                name: 'POSTGRES_PASSWORD',
                valueFrom: { secretKeyRef: { name: 'woodpecker-postgres-env', key: 'POSTGRES_PASSWORD' } },
              },
              { name: 'PGDATA', value: '/var/lib/postgresql/data/pgdata' },
            ],
            readinessProbe: {
              exec: { command: ['pg_isready', '-U', 'woodpecker', '-d', 'woodpecker'] },
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
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'woodpecker-postgres' } }],
        },
      },
    },
  },
}
