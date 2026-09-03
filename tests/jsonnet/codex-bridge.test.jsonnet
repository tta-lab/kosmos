local resources = import '../../tanka/environments/codex-bridge/main.jsonnet';
local deployment = resources.codexBridgeDeployment;
local containers = {
  [container.name]: container
  for container in deployment.spec.template.spec.containers
};
local bridge = containers.bridge;
local relay = containers['loopback-relay'];
local service = resources.codexBridgeService;
local secrets = [
  resources[field]
  for field in std.objectFields(resources)
  if resources[field].kind == 'Secret'
];

std.assertEqual(resources.namespace.metadata.name, 'codex-bridge') &&
std.assertEqual(deployment.spec.replicas, 1) &&
std.assertEqual(deployment.spec.strategy.type, 'Recreate') &&
std.assertEqual(deployment.spec.template.spec.automountServiceAccountToken, false) &&
std.assertEqual(
  bridge.image,
  'ghcr.io/lamplitisles/kepos-codex-bridge:sha-dae3c3aa786209884c4e343cfcd868c45f27f06f@sha256:fb58f432052f89d2e959edbe1b4ac2dee350370ab1fe83336304fdb1f4f95047'
) &&
std.assertEqual(bridge.args, [
  'serve',
  '--auth-file',
  '/home/neil/.codex/auth.json',
  '--port',
  '8787',
]) &&
std.assertEqual(bridge.imagePullPolicy, 'IfNotPresent') &&
std.assertEqual(bridge.securityContext.runAsUser, 1000) &&
std.assertEqual(bridge.securityContext.runAsGroup, 100) &&
std.assertEqual(
  [mount for mount in bridge.volumeMounts if mount.name == 'codex-home'][0].mountPath,
  '/home/neil/.codex'
) &&
std.assertEqual(
  [volume for volume in deployment.spec.template.spec.volumes if volume.name == 'codex-home'][0].hostPath,
  {
    path: '/home/neil/.codex',
    type: 'Directory',
  }
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
std.assertEqual(std.length(secrets), 0)
