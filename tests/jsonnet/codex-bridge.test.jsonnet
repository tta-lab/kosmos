local resources = import '../../tanka/environments/codex-bridge/main.jsonnet';
local deployment = resources.codexBridgeDeployment;
local containers = {
  [container.name]: container
  for container in deployment.spec.template.spec.containers
};
local bridge = containers.bridge;
local relay = containers['loopback-relay'];
local service = resources.codexBridgeService;
local pv = resources.codexBridgePv;
local pvc = resources.codexBridgePvc;
local secrets = [
  resources[field]
  for field in std.objectFields(resources)
  if resources[field].kind == 'Secret'
];

std.assertEqual(resources.namespace.metadata.name, 'codex-bridge') &&
std.assertEqual(deployment.spec.replicas, 0) &&
std.assertEqual(deployment.spec.strategy.type, 'Recreate') &&
std.assertEqual(deployment.spec.template.spec.automountServiceAccountToken, false) &&
std.assertEqual(bridge.image, 'ghcr.io/lamplitisles/kepos-codex-bridge:ghcr-placeholder') &&
std.assertEqual(bridge.args, [
  'serve',
  '--auth-file',
  '/var/lib/kepos-codex-bridge/auth.json',
  '--port',
  '8787',
]) &&
std.assertEqual(bridge.securityContext.runAsUser, 10001) &&
std.assertEqual(
  [mount for mount in bridge.volumeMounts if mount.name == 'state'][0].mountPath,
  '/var/lib/kepos-codex-bridge'
) &&
std.assertEqual(
  relay.image,
  'docker.io/alpine/socat:1.8.0.3@sha256:beb4a68d9e4fe6b0f21ea774a0fde6c31f580dde6368939ed70100c5385b015e'
) &&
std.assertEqual([port for port in relay.ports if port.name == 'proxy'][0].containerPort, 8788) &&
std.assertEqual(
  std.length([
    command
    for command in relay.readinessProbe.exec.command
    if std.findSubstr('TCP:127.0.0.1:8787', command) != []
  ]),
  1
) &&
std.assertEqual(service.spec.type, 'ClusterIP') &&
std.assertEqual([port for port in service.spec.ports if port.name == 'http'][0], {
  name: 'http',
  port: 8787,
  targetPort: 'proxy',
}) &&
std.assertEqual(pv.spec.persistentVolumeReclaimPolicy, 'Retain') &&
std.assertEqual(pv.spec.hostPath.path, '/var/lib/kosmos-k3s/codex-bridge') &&
std.assertEqual(pvc.spec.volumeName, 'kosmos-codex-bridge') &&
std.assertEqual(std.length(secrets), 0)
