local resources = import '../../tanka/environments/devops/main.jsonnet';
local caddy = resources.gatewayConfig.data.Caddyfile;
local dns = resources.coreDnsOverrides.data['kosmos.override'];
local deployment = resources.gatewayDeployment;
local container = deployment.spec.template.spec.containers[0];
local configMount = [mount for mount in container.volumeMounts if mount.name == 'config'][0];
local contains(haystack, needle) = std.findSubstr(needle, haystack) != [];

std.assertEqual(contains(caddy, '@hindsight host hindsight.localhost'), true) &&
std.assertEqual(
  contains(caddy, 'reverse_proxy hindsight.hindsight.svc.cluster.local:8888'),
  true
) &&
std.assertEqual(contains(caddy, '@hindsightui host hindsightui.localhost'), true) &&
std.assertEqual(
  contains(caddy, 'reverse_proxy hindsight.hindsight.svc.cluster.local:9999'),
  true
) &&
std.assertEqual(
  contains(caddy, '@codexBridge host codex-bridge.localhost codex-bridge.kepos.internal'),
  true
) &&
std.assertEqual(
  contains(caddy, 'reverse_proxy codex-bridge.codex-bridge.svc.cluster.local:8787'),
  true
) &&
std.assertEqual(
  contains(dns, 'rewrite name exact hindsight.localhost canonical-gateway.devops.svc.cluster.local'),
  true
) &&
std.assertEqual(
  contains(dns, 'rewrite name exact hindsightui.localhost canonical-gateway.devops.svc.cluster.local'),
  true
) &&
std.assertEqual(
  contains(dns, 'rewrite name exact codex-bridge.localhost canonical-gateway.devops.svc.cluster.local'),
  true
) &&
std.assertEqual(std.member(container.args, '--watch'), true) &&
std.assertEqual(configMount, {
  name: 'config',
  mountPath: '/etc/caddy',
  readOnly: true,
})
