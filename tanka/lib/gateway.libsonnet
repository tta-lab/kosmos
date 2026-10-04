local routes = import '../../http/cluster-routes.json';
local ingress = import 'ingress.libsonnet';
local hosts = std.flattenArrays([routes[id].hosts for id in std.objectFields(routes)]);

{
  coreDnsOverrides: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: { name: 'coredns-custom', namespace: 'kube-system' },
    data: {
      'kosmos.override': std.join('\n', [
        'rewrite name exact ' + host + ' cluster-http.devops.svc.cluster.local'
        for host in hosts
      ]) + '\n',
    },
  },
  // ERPNext's workload is managed outside this repository; own only its route.
  erpnextIngress: ingress('erpnext'),
} + (import 'traefik.libsonnet')
