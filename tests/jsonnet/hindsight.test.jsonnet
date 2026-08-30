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
std.assertEqual(container.image, 'localhost/kosmos/hindsight:0.1.1') &&
std.assertEqual(container.imagePullPolicy, 'Never') &&
std.assertEqual(container.securityContext.runAsNonRoot, true) &&
std.assertEqual(container.startupProbe.httpGet.path, '/health') &&
std.assertEqual(env.HINDSIGHT_API_DATABASE_URL.valueFrom.secretKeyRef, {
  name: 'hindsight-database',
  key: 'HINDSIGHT_API_DATABASE_URL',
}) &&
std.assertEqual(env.HINDSIGHT_API_VECTOR_EXTENSION.value, 'pgvector') &&
std.assertEqual(env.HINDSIGHT_API_TEXT_SEARCH_EXTENSION.value, 'pgroonga') &&
std.assertEqual(env.HINDSIGHT_API_EMBEDDINGS_PROVIDER.value, 'local') &&
std.assertEqual(env.HINDSIGHT_API_EMBEDDINGS_LOCAL_MODEL.value, '/opt/hindsight-models/paraphrase-multilingual-MiniLM-L12-v2') &&
std.assertEqual(env.HINDSIGHT_API_EMBEDDINGS_LOCAL_FORCE_CPU.value, '1') &&
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
