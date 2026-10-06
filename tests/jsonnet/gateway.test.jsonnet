local resources = import '../../tanka/environments/devops/main.jsonnet';
local container = resources.ingressDeployment.spec.template.spec.containers[0];
local routes = import '../../http/cluster-routes.json';
local hosts = std.flattenArrays([routes[id].hosts for id in std.objectFields(routes)]);
local dns = resources.coreDnsOverrides.data['kosmos.override'];

std.assertEqual(resources.ingressService.spec.selector, resources.ingressDeployment.spec.selector.matchLabels) &&
std.assertEqual(resources.ingressService.spec.type, 'ClusterIP') &&
std.assertEqual(resources.ingressService.spec.ports[0], { name: 'http', port: 17480, targetPort: 'http' }) &&
std.assertEqual(container.ports[0], { name: 'http', containerPort: 17480, hostPort: 27480, hostIP: '127.0.0.1' }) &&
std.assertEqual(container.securityContext.runAsNonRoot, true) &&
std.assertEqual(resources.ingressClass.spec.controller, 'traefik.io/ingress-controller') &&
std.assertEqual(std.length(std.split(dns, '\n')) - 1, std.length(hosts)) &&
std.assertEqual(resources.erpnextIngress.metadata.namespace, 'erpnext')
