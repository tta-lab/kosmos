local routes = import '../../http/cluster-routes.json';
local ingress = import 'ingress.libsonnet';
local hosts = std.flattenArrays([routes[id].hosts for id in std.objectFields(routes)]);

{
  coreDnsOverrides: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: { name: 'coredns-custom', namespace: 'kube-system' },
    data: {
      // Museum's TLS S3 consumer must reach host Caddy, not HTTP-only Traefik.
      'nuc-storage.server': |||
        ente-storage.nuc.swdl:53 {
          errors
          cache 30
          hosts {
            10.80.12.4 ente-storage.nuc.swdl
          }
        }
      |||,
      'kosmos.override': std.join('\n', [
        'rewrite name exact ' + host + ' cluster-http.devops.svc.cluster.local'
        for host in hosts
      ]) + '\n',
    },
  },
  // ERPNext's workload is managed outside this repository; own only its route.
  erpnextIngress: ingress('erpnext'),
} + (import 'traefik.libsonnet')
