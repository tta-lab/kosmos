local resources = import '../../tanka/environments/clipcascade/main.jsonnet';
local deployment = resources.clipcascadeDeployment;
local container = deployment.spec.template.spec.containers[0];
local env = {
  [variable.name]: variable
  for variable in container.env
};
local volumes = {
  [volume.name]: volume
  for volume in deployment.spec.template.spec.volumes
};
local mounts = {
  [mount.name]: mount
  for mount in container.volumeMounts
};
local secrets = [
  resources[field]
  for field in std.objectFields(resources)
  if resources[field].kind == 'Secret'
];

std.assertEqual(resources.namespace.metadata.name, 'clipcascade') &&
std.assertEqual(deployment.spec.replicas, 1) &&
std.assertEqual(deployment.spec.strategy.type, 'Recreate') &&
std.assertEqual(resources.clipcascadeService.spec.type, 'ClusterIP') &&
std.assertEqual(resources.clipcascadeService.spec.ports[0], {
  name: 'http',
  port: 8080,
  targetPort: 'http',
}) &&
std.assertEqual(resources.clipcascadeService.spec.selector, deployment.spec.selector.matchLabels) &&
std.assertEqual(container.imagePullPolicy, 'Never') &&
std.assertEqual(env.CC_PORT.value, '8080') &&
std.assertEqual(env.CC_P2P_ENABLED.value, 'false') &&
std.assertEqual(env.CC_ALLOWED_ORIGINS.value, 'http://clipcascade.localhost:17480') &&
std.assertEqual(env.CC_EXTERNAL_BROKER_ENABLED.value, 'false') &&
std.assertEqual(env.CC_SERVER_DB_URL.value, 'jdbc:h2:file:/database/clipcascade;CIPHER=AES;MODE=PostgreSQL') &&
std.assertEqual(env.CC_SERVER_DB_USERNAME.value, 'clipcascade') &&
std.assertEqual(env.CC_SERVER_DB_PASSWORD.valueFrom.secretKeyRef, {
  name: 'clipcascade-database',
  key: 'CC_SERVER_DB_PASSWORD',
}) &&
std.assertEqual(container.startupProbe.httpGet.path, '/health') &&
std.assertEqual(container.readinessProbe.httpGet.path, '/health') &&
std.assertEqual(container.livenessProbe.httpGet.path, '/health') &&
std.assertEqual(container.securityContext.runAsNonRoot, true) &&
std.assertEqual(container.securityContext.runAsUser, 10001) &&
std.assertEqual(container.securityContext.runAsGroup, 10001) &&
std.assertEqual(container.securityContext.readOnlyRootFilesystem, true) &&
std.assertEqual(deployment.spec.template.spec.automountServiceAccountToken, false) &&
std.assertEqual(mounts.database.mountPath, '/database') &&
std.assertEqual(mounts.logs.mountPath, '/app/logs') &&
std.assertEqual(mounts.tmp.mountPath, '/tmp') &&
std.assertEqual(volumes.database.persistentVolumeClaim.claimName, 'clipcascade-data') &&
std.assertEqual(volumes.logs.emptyDir.medium, 'Memory') &&
std.assertEqual(volumes.tmp.emptyDir.medium, 'Memory') &&
std.assertEqual(resources.clipcascadePv.spec.hostPath.path, '/var/lib/kosmos-k3s/clipcascade') &&
std.assertEqual(resources.clipcascadePv.spec.hostPath.type, 'Directory') &&
std.assertEqual(resources.clipcascadePv.spec.persistentVolumeReclaimPolicy, 'Retain') &&
std.assertEqual(resources.clipcascadePvc.spec.volumeName, 'kosmos-clipcascade') &&
std.assertEqual(std.length(secrets), 0)
