local resources = import '../../tanka/environments/impri/main.jsonnet';
local server = resources.serverDeployment;
local serverContainer = server.spec.template.spec.containers[0];
local serverEnv = {
  [variable.name]: variable
  for variable in serverContainer.env
};
local ui = resources.uiDeployment;
local uiContainer = ui.spec.template.spec.containers[0];
local secrets = [
  resources[field]
  for field in std.objectFields(resources)
  if resources[field].kind == 'Secret'
];

std.assertEqual(resources.namespace.metadata.name, 'impri') &&
std.assertEqual(server.spec.replicas, 1) &&
std.assertEqual(server.spec.strategy.type, 'Recreate') &&
std.assertEqual(resources.serverService.spec.selector, server.spec.selector.matchLabels) &&
std.assertEqual(serverContainer.image, 'localhost/kosmos/impri-server:81d94150') &&
std.assertEqual(serverContainer.imagePullPolicy, 'Never') &&
std.assertEqual(serverContainer.securityContext.runAsNonRoot, true) &&
std.assertEqual(serverContainer.startupProbe.httpGet.path, '/readyz') &&
std.assertEqual(serverContainer.readinessProbe.httpGet.path, '/readyz') &&
std.assertEqual(serverEnv.BASE_URL.value, 'http://impri.localhost:17480') &&
std.assertEqual(serverEnv.DISABLE_WATCHER_SCHEDULER.value, '1') &&
std.assertEqual(serverEnv.WEBHOOK_SECRET.valueFrom.secretKeyRef, {
  name: 'impri-runtime',
  key: 'WEBHOOK_SECRET',
}) &&
std.assertEqual(resources.impriPv.spec.hostPath.path, '/var/lib/kosmos-k3s/impri') &&
std.assertEqual(resources.impriPv.spec.persistentVolumeReclaimPolicy, 'Retain') &&
std.assertEqual(resources.impriPvc.spec.volumeName, 'kosmos-impri') &&
std.assertEqual(uiContainer.image, 'localhost/kosmos/impri-ui:81d94150') &&
std.assertEqual(uiContainer.imagePullPolicy, 'Never') &&
std.assertEqual(resources.uiService.spec.selector, ui.spec.selector.matchLabels) &&
std.assertEqual(std.length(secrets), 0)
