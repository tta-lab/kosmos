local legacyStorage = import 'hindsight-storage.libsonnet';
local postgresStorage = import 'hindsight-postgres-storage.libsonnet';
local proxy = import 'proxy.libsonnet';

local baseLabels = {
  'app.kubernetes.io/name': 'hindsight',
  'app.kubernetes.io/part-of': 'kosmos-hindsight',
};
local labels(role) = baseLabels + { 'kosmos.tta-lab.org/role': role };
// Keep the legacy Deployment selector byte-for-byte compatible with the
// existing pg0 workload: Kubernetes does not allow selector changes in place.
// The multilingual pods use a distinct name label so the old selector cannot
// accidentally adopt them during the blue-green window.
local legacySelector = baseLabels;
local legacyLabels = labels('legacy');
local multilingualLabels = labels('multilingual') + {
  'app.kubernetes.io/name': 'hindsight-multilingual',
};
local postgresLabels = {
  'app.kubernetes.io/name': 'hindsight-postgres',
  'app.kubernetes.io/part-of': 'kosmos-hindsight',
};

local hindsightImage = 'kosmos/hindsight:0.1.0';
local postgresImage = 'kosmos/hindsight-postgres:0.1.0';
local databaseSecretName = 'hindsight-database';

local service(selector, name='hindsight') = {
  apiVersion: 'v1',
  kind: 'Service',
  metadata: {
    name: name,
    namespace: 'hindsight',
    labels: baseLabels + { 'kosmos.tta-lab.org/stage-service': name },
  },
  spec: {
    type: 'ClusterIP',
    selector: selector,
    ports: [
      { name: 'api', port: 8888, targetPort: 'api' },
      { name: 'ui', port: 9999, targetPort: 'ui' },
    ],
  },
};

local legacyEnv = [
  { name: 'HINDSIGHT_API_LLM_PROVIDER', value: 'openai-responses' },
  { name: 'HINDSIGHT_API_LLM_BASE_URL', value: 'http://codex-bridge.localhost:17480/hindsight' },
  { name: 'HINDSIGHT_API_LLM_MODEL', value: 'gpt-5.6-luna' },
  { name: 'HINDSIGHT_API_LLM_REASONING_EFFORT', value: 'high' },
  { name: 'HINDSIGHT_API_LLM_API_KEY', value: 'bridge-managed-oauth' },
  { name: 'HINDSIGHT_API_LLM_TIMEOUT', value: '300' },
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
];

local secretEnv(name, key) = {
  name: name,
  valueFrom: {
    secretKeyRef: {
      name: databaseSecretName,
      key: key,
    },
  },
};

local multilingualEnv = legacyEnv + [
  secretEnv('HINDSIGHT_API_DATABASE_URL', 'HINDSIGHT_API_DATABASE_URL'),
  { name: 'HINDSIGHT_API_VECTOR_EXTENSION', value: 'pgvector' },
  { name: 'HINDSIGHT_API_TEXT_SEARCH_EXTENSION', value: 'pgroonga' },
  { name: 'HINDSIGHT_API_EMBEDDINGS_PROVIDER', value: 'local' },
  {
    name: 'HINDSIGHT_API_EMBEDDINGS_LOCAL_MODEL',
    value: 'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2',
  },
  { name: 'HINDSIGHT_API_EMBEDDINGS_LOCAL_FORCE_CPU', value: '1' },
  { name: 'HINDSIGHT_API_MODEL_INIT_TIMEOUT', value: '300' },
  { name: 'HF_HOME', value: '/home/hindsight/.cache/huggingface' },
  { name: 'TRANSFORMERS_CACHE', value: '/home/hindsight/.cache/huggingface' },
  { name: 'CUDA_VISIBLE_DEVICES', value: '' },
];

local probes = {
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
    failureThreshold: 6,
  },
  livenessProbe: {
    httpGet: { path: '/health', port: 'api' },
    periodSeconds: 30,
    timeoutSeconds: 5,
    failureThreshold: 3,
  },
};
local legacyProbes = probes + {
  readinessProbe+: { failureThreshold: 3 },
};

local legacyDeployment(replicas) = {
  apiVersion: 'apps/v1',
  kind: 'Deployment',
  metadata: {
    name: 'hindsight',
    namespace: 'hindsight',
    labels: legacyLabels,
  },
  spec: {
    replicas: replicas,
    strategy: { type: 'Recreate' },
    selector: { matchLabels: legacySelector },
    template: {
      metadata: { labels: legacyLabels },
      spec: {
        terminationGracePeriodSeconds: 120,
        securityContext: {
          fsGroup: 1000,
          fsGroupChangePolicy: 'OnRootMismatch',
        },
        containers: [{
          name: 'hindsight',
          image: hindsightImage,
          imagePullPolicy: 'Never',
          ports: [
            { name: 'api', containerPort: 8888 },
            { name: 'ui', containerPort: 9999 },
          ],
          env: legacyEnv,
        } + legacyProbes + {
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
};

local multilingualDeployment = {
  apiVersion: 'apps/v1',
  kind: 'Deployment',
  metadata: {
    name: 'hindsight-multilingual',
    namespace: 'hindsight',
    labels: multilingualLabels,
  },
  spec: {
    replicas: 1,
    strategy: { type: 'Recreate' },
    selector: { matchLabels: multilingualLabels },
    template: {
      metadata: { labels: multilingualLabels },
      spec: {
        automountServiceAccountToken: false,
        terminationGracePeriodSeconds: 120,
        securityContext: {
          fsGroup: 1000,
          fsGroupChangePolicy: 'OnRootMismatch',
        },
        containers: [{
          name: 'hindsight',
          image: hindsightImage,
          imagePullPolicy: 'Never',
          ports: [
            { name: 'api', containerPort: 8888 },
            { name: 'ui', containerPort: 9999 },
          ],
          env: multilingualEnv,
        } + probes + {
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
            { name: 'tmp', mountPath: '/tmp' },
            { name: 'shm', mountPath: '/dev/shm' },
          ],
        }],
        volumes: [
          { name: 'tmp', emptyDir: { sizeLimit: '1Gi' } },
          { name: 'shm', emptyDir: { medium: 'Memory', sizeLimit: '1Gi' } },
        ],
      },
    },
  },
};

local postgresService = {
  apiVersion: 'v1',
  kind: 'Service',
  metadata: {
    name: 'hindsight-postgres',
    namespace: 'hindsight',
    labels: postgresLabels,
  },
  spec: {
    type: 'ClusterIP',
    selector: postgresLabels,
    ports: [{ name: 'postgres', port: 5432, targetPort: 'postgres' }],
  },
};

local postgresProbeCommand = [
  'sh',
  '-ec',
  'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" && test "$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT extversion FROM pg_extension WHERE extname = ' + "'pgroonga'" + '")" = "4.0.8" && test "$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT extversion FROM pg_extension WHERE extname = ' + "'vector'" + '")" = "0.8.6"',
];

local postgresStatefulSet = {
  apiVersion: 'apps/v1',
  kind: 'StatefulSet',
  metadata: {
    name: 'hindsight-postgres',
    namespace: 'hindsight',
    labels: postgresLabels,
  },
  spec: {
    serviceName: 'hindsight-postgres',
    replicas: 1,
    selector: { matchLabels: postgresLabels },
    template: {
      metadata: { labels: postgresLabels },
      spec: {
        automountServiceAccountToken: false,
        securityContext: {
          runAsNonRoot: true,
          runAsUser: 999,
          runAsGroup: 999,
          fsGroup: 999,
          fsGroupChangePolicy: 'OnRootMismatch',
        },
        containers: [{
          name: 'postgres',
          image: postgresImage,
          imagePullPolicy: 'Never',
          ports: [{ name: 'postgres', containerPort: 5432 }],
          env: [
            { name: 'POSTGRES_USER', value: 'hindsight' },
            secretEnv('POSTGRES_PASSWORD', 'POSTGRES_PASSWORD'),
            secretEnv('PGPASSWORD', 'POSTGRES_PASSWORD'),
            { name: 'POSTGRES_DB', value: 'hindsight' },
            { name: 'PGDATA', value: '/var/lib/postgresql/data/pgdata' },
          ],
          args: [
            '-c', 'shared_preload_libraries=pgroonga_wal_resource_manager,pgroonga_crash_safer',
            '-c', 'pgroonga.enable_wal=on',
          ],
          startupProbe: {
            exec: { command: postgresProbeCommand },
            periodSeconds: 5,
            timeoutSeconds: 5,
            failureThreshold: 60,
          },
          readinessProbe: {
            exec: { command: postgresProbeCommand },
            periodSeconds: 10,
            timeoutSeconds: 5,
            failureThreshold: 6,
          },
          livenessProbe: {
            exec: { command: ['pg_isready', '-U', 'hindsight', '-d', 'hindsight'] },
            periodSeconds: 30,
            timeoutSeconds: 5,
            failureThreshold: 3,
          },
          resources: {
            requests: { cpu: '100m', memory: '512Mi' },
            limits: { cpu: '2', memory: '2Gi' },
          },
          securityContext: {
            allowPrivilegeEscalation: false,
            capabilities: { drop: ['ALL'] },
            seccompProfile: { type: 'RuntimeDefault' },
          },
          volumeMounts: [{ name: 'data', mountPath: '/var/lib/postgresql/data' }],
        }],
        volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'hindsight-postgres-data' } }],
      },
    },
  },
};

local stage(legacyReplicas, canonicalSelector) = {
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: { name: 'hindsight' },
  },
  hindsightService: service(canonicalSelector),
  hindsightDeployment: legacyDeployment(legacyReplicas),
  hindsightCandidateService: service(multilingualLabels, 'hindsight-candidate'),
  hindsightMultilingualDeployment: multilingualDeployment,
  hindsightPostgresService: postgresService,
  hindsightPostgres: postgresStatefulSet,
} + legacyStorage + postgresStorage;

{
  candidate: stage(1, legacySelector),
  final: stage(0, multilingualLabels),
}
