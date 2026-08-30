local resources = import '../../tanka/environments/hindsight/main.jsonnet';
local deployment = resources.hindsightDeployment;
local container = deployment.spec.template.spec.containers[0];
local env = {
  [variable.name]: variable
  for variable in container.env
};
local service = resources.hindsightService;
local pv = resources.hindsightPv;
local pvc = resources.hindsightPvc;
local secrets = [
  resources[field]
  for field in std.objectFields(resources)
  if resources[field].kind == 'Secret'
];
local stages = import '../../tanka/lib/hindsight.libsonnet';
local candidate = stages.candidate;
local final = stages.final;
local multilingual = candidate.hindsightMultilingualDeployment;
local multilingualContainer = multilingual.spec.template.spec.containers[0];
local multilingualEnv = {
  [variable.name]: variable
  for variable in multilingualContainer.env
};
local postgres = candidate.hindsightPostgres;
local postgresContainer = postgres.spec.template.spec.containers[0];
local postgresEnv = {
  [variable.name]: variable
  for variable in postgresContainer.env
};

std.assertEqual(resources.namespace.metadata.name, 'hindsight') &&
std.assertEqual(deployment.spec.replicas, 1) &&
std.assertEqual(deployment.spec.strategy.type, 'Recreate') &&
std.assertEqual(
  container.image,
  'kosmos/hindsight:0.1.0'
) &&
std.assertEqual(container.imagePullPolicy, 'Never') &&
std.assertEqual(container.securityContext.runAsNonRoot, true) &&
std.assertEqual(container.startupProbe.httpGet.path, '/health') &&
std.assertEqual(container.readinessProbe.httpGet.path, '/health') &&
std.assertEqual(container.readinessProbe.failureThreshold, 3) &&
std.assertEqual(container.livenessProbe.httpGet.path, '/health') &&
std.assertEqual([port for port in container.ports if port.name == 'api'][0], {
  name: 'api',
  containerPort: 8888,
}) &&
std.assertEqual([port for port in container.ports if port.name == 'ui'][0], {
  name: 'ui',
  containerPort: 9999,
}) &&
std.assertEqual(env.HINDSIGHT_API_LLM_PROVIDER.value, 'openai-responses') &&
std.assertEqual(env.HINDSIGHT_API_LLM_BASE_URL.value, 'http://codex-bridge.localhost:17480/hindsight') &&
std.assertEqual(env.HINDSIGHT_API_LLM_MODEL.value, 'gpt-5.6-luna') &&
std.assertEqual(env.HINDSIGHT_API_LLM_REASONING_EFFORT.value, 'high') &&
std.assertEqual(env.HINDSIGHT_API_LLM_API_KEY.value, 'bridge-managed-oauth') &&
std.assertEqual(env.HINDSIGHT_API_LLM_TIMEOUT.value, '300') &&
!std.objectHas(env, 'HINDSIGHT_API_RETAIN_LLM_TIMEOUT') &&
!std.objectHas(env, 'HINDSIGHT_API_CONSOLIDATION_LLM_TIMEOUT') &&
std.assertEqual(env.HINDSIGHT_API_WORKER_ID.value, 'hindsight') &&
std.assertEqual(env.HTTPS_PROXY.value, 'http://10.42.0.1:7890') &&
std.assertEqual(std.findSubstr('localhost', env.NO_PROXY.value) != [], true) &&
std.assertEqual(std.findSubstr('.cluster.local', env.NO_PROXY.value) != [], true) &&
std.assertEqual(std.findSubstr('.localhost', env.NO_PROXY.value) != [], true) &&
std.assertEqual(env.HF_HUB_OFFLINE.value, '1') &&
std.assertEqual(env.TRANSFORMERS_OFFLINE.value, '1') &&
std.assertEqual(
  [mount for mount in container.volumeMounts if mount.name == 'data'][0].mountPath,
  '/home/hindsight/.pg0'
) &&
std.assertEqual(container.resources.requests.memory, '4Gi') &&
std.assertEqual(service.spec.type, 'ClusterIP') &&
std.assertEqual([port for port in service.spec.ports if port.name == 'api'][0].port, 8888) &&
std.assertEqual([port for port in service.spec.ports if port.name == 'ui'][0].port, 9999) &&
std.assertEqual(pv.spec.persistentVolumeReclaimPolicy, 'Retain') &&
std.assertEqual(pv.spec.hostPath.path, '/var/lib/kosmos-k3s/hindsight') &&
std.assertEqual(pvc.spec.volumeName, 'kosmos-hindsight') &&
std.assertEqual(std.length(secrets), 0) &&
std.assertEqual(candidate.hindsightService.spec.selector, candidate.hindsightDeployment.spec.selector.matchLabels) &&
std.assertEqual(candidate.hindsightDeployment.spec.selector.matchLabels, {
  'app.kubernetes.io/name': 'hindsight',
  'app.kubernetes.io/part-of': 'kosmos-hindsight',
}) &&
std.assertEqual(final.hindsightService.spec.selector, final.hindsightMultilingualDeployment.spec.selector.matchLabels) &&
std.assertEqual(final.hindsightDeployment.spec.replicas, 0) &&
std.assertEqual(candidate.hindsightDeployment.spec.replicas, 1) &&
std.assertEqual(candidate.hindsightCandidateService.metadata.name, 'hindsight-candidate') &&
std.assertEqual(candidate.hindsightCandidateService.spec.selector, multilingual.spec.selector.matchLabels) &&
std.assertEqual(multilingualContainer.image, 'kosmos/hindsight:0.1.0') &&
std.assertEqual(multilingualContainer.imagePullPolicy, 'Never') &&
std.assertEqual(multilingual.spec.selector.matchLabels['app.kubernetes.io/name'], 'hindsight-multilingual') &&
std.assertEqual(multilingualContainer.securityContext.runAsNonRoot, true) &&
std.assertEqual(multilingualContainer.securityContext.capabilities.drop, ['ALL']) &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef, {
  name: 'hindsight-database',
  key: 'HINDSIGHT_API_DATABASE_URL',
}) &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_VECTOR_EXTENSION.value, 'pgvector') &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_TEXT_SEARCH_EXTENSION.value, 'pgroonga') &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_EMBEDDINGS_PROVIDER.value, 'local') &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_EMBEDDINGS_LOCAL_MODEL.value, 'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2') &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_EMBEDDINGS_LOCAL_FORCE_CPU.value, '1') &&
std.assertEqual(multilingualEnv.HF_HUB_OFFLINE.value, '1') &&
std.assertEqual(multilingualEnv.TRANSFORMERS_OFFLINE.value, '1') &&
std.assertEqual(multilingualEnv.HINDSIGHT_API_RERANKER_PROVIDER.value, 'rrf') &&
std.assertEqual(std.length(multilingualContainer.volumeMounts), 2) &&
std.assertEqual(postgres.metadata.name, 'hindsight-postgres') &&
std.assertEqual(postgres.spec.replicas, 1) &&
std.assertEqual(postgresContainer.image, 'kosmos/hindsight-postgres:0.1.0') &&
std.assertEqual(postgresContainer.imagePullPolicy, 'Never') &&
std.assertEqual(postgresContainer.securityContext.capabilities.drop, ['ALL']) &&
std.assertEqual(postgresEnv.POSTGRES_PASSWORD.valueFrom.secretKeyRef, {
  name: 'hindsight-database',
  key: 'POSTGRES_PASSWORD',
}) &&
std.assertEqual(postgresEnv.PGPASSWORD.valueFrom.secretKeyRef, {
  name: 'hindsight-database',
  key: 'POSTGRES_PASSWORD',
}) &&
std.assertEqual(postgresContainer.startupProbe.exec.command[0], 'sh') &&
std.assertEqual(std.findSubstr('pg_isready', postgresContainer.readinessProbe.exec.command[2]) != [], true) &&
std.assertEqual(std.findSubstr('4.0.8', postgresContainer.readinessProbe.exec.command[2]) != [], true) &&
std.assertEqual(std.findSubstr('0.8.6', postgresContainer.readinessProbe.exec.command[2]) != [], true) &&
std.assertEqual(candidate.hindsightPostgresService.spec.type, 'ClusterIP') &&
std.assertEqual(candidate.hindsightPostgresService.spec.ports[0].port, 5432) &&
std.assertEqual(candidate.hindsightPostgresPv.spec.persistentVolumeReclaimPolicy, 'Retain') &&
std.assertEqual(candidate.hindsightPostgresPv.spec.hostPath.path, '/var/lib/kosmos-k3s/hindsight-postgres') &&
std.assertEqual(candidate.hindsightPostgresPvc.spec.volumeName, 'kosmos-hindsight-postgres') &&
std.assertEqual(candidate.hindsightPostgresPvc.spec.storageClassName, 'kosmos-static')
