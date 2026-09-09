local resources = import '../../tanka/environments/hindsight/main.jsonnet';
local deployment = resources.hindsightDeployment;
local container = deployment.spec.template.spec.containers[0];
local env = {
  [variable.name]: variable
  for variable in container.env
};
local postgres = resources.hindsightPostgres;
local postgresContainer = postgres.spec.template.spec.containers[0];
local postgresEnv = {
  [variable.name]: variable
  for variable in postgresContainer.env
};
local secrets = [
  resources[field]
  for field in std.objectFields(resources)
  if resources[field].kind == 'Secret'
];

std.assertEqual(resources.namespace.metadata.name, 'hindsight') &&
std.assertEqual(deployment.metadata.name, 'hindsight-multilingual') &&
std.assertEqual(deployment.spec.replicas, 1) &&
std.assertEqual(resources.hindsightService.spec.selector, deployment.spec.selector.matchLabels) &&
std.assertEqual(std.length(std.findSubstr('@sha256:', container.image)), 1) &&
std.assertEqual(container.imagePullPolicy, 'IfNotPresent') &&
std.assertEqual(container.securityContext.runAsNonRoot, true) &&
std.assertEqual(container.startupProbe.httpGet.path, '/health') &&
std.assertEqual(env.HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef, {
  name: 'hindsight-database',
  key: 'HINDSIGHT_API_DATABASE_URL',
}) &&
std.assertEqual(env.HINDSIGHT_API_VECTOR_EXTENSION.value, 'pgvector') &&
std.assertEqual(env.HINDSIGHT_API_TEXT_SEARCH_EXTENSION.value, 'pgroonga') &&
std.assertEqual(env.HINDSIGHT_API_LLM_BASE_URL.value, 'http://codex-bridge.localhost:17480/codex/buffered') &&
std.assertEqual(env.HINDSIGHT_API_REFLECT_LLM_PROVIDER.value, 'deepseek') &&
std.assertEqual(env.HINDSIGHT_API_REFLECT_LLM_BASE_URL.value, 'https://api.deepseek.com') &&
std.assertEqual(env.HINDSIGHT_API_REFLECT_LLM_MODEL.value, 'deepseek-v4-flash') &&
std.assertEqual(env.HINDSIGHT_API_REFLECT_LLM_API_KEY.valueFrom.secretKeyRef, {
  name: 'hindsight-deepseek',
  key: 'api-key',
}) &&
std.assertEqual(env.HINDSIGHT_API_EMBEDDINGS_PROVIDER.value, 'onnx') &&
std.assertEqual(env.HINDSIGHT_API_EMBEDDINGS_ONNX_INTRA_OP_THREADS.value, container.resources.limits.cpu) &&
std.assertEqual(env.HINDSIGHT_API_RERANKER_PROVIDER.value, 'rrf') &&
std.assertEqual(std.length(container.volumeMounts), 2) &&
std.assertEqual(postgres.metadata.name, 'hindsight-postgres') &&
std.assertEqual(postgres.spec.replicas, 1) &&
std.assertEqual(postgresContainer.image, 'localhost/kosmos/hindsight-postgres:0.1.1') &&
std.assertEqual(postgresEnv.POSTGRES_PASSWORD.valueFrom.secretKeyRef, {
  name: 'hindsight-database',
  key: 'POSTGRES_PASSWORD',
}) &&
std.assertEqual(std.findSubstr('4.0.8', postgresContainer.readinessProbe.exec.command[2]) != [], true) &&
std.assertEqual(std.findSubstr('0.8.6', postgresContainer.readinessProbe.exec.command[2]) != [], true) &&
std.assertEqual(resources.hindsightPostgresPv.spec.hostPath.path, '/var/lib/kosmos-k3s/hindsight-postgres') &&
std.assertEqual(resources.hindsightPostgresPvc.spec.volumeName, 'kosmos-hindsight-postgres') &&
std.assertEqual(std.length(secrets), 0)
