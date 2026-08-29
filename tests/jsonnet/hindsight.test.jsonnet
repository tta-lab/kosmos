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

std.assertEqual(resources.namespace.metadata.name, 'hindsight') &&
std.assertEqual(deployment.spec.replicas, 1) &&
std.assertEqual(deployment.spec.strategy.type, 'Recreate') &&
std.assertEqual(
  container.image,
  'ghcr.io/vectorize-io/hindsight:0.9.2@sha256:84ab276b8f501546deb6ea9c64a57291718b4e16a59dd9e02a02fdd5adfe9028'
) &&
std.assertEqual(container.securityContext.runAsNonRoot, true) &&
std.assertEqual(container.startupProbe.httpGet.path, '/health') &&
std.assertEqual(container.readinessProbe.httpGet.path, '/health') &&
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
std.assertEqual(env.HINDSIGHT_API_LLM_REASONING_EFFORT.value, 'xhigh') &&
std.assertEqual(env.HINDSIGHT_API_LLM_API_KEY.value, 'bridge-managed-oauth') &&
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
std.assertEqual(std.length(secrets), 0)
