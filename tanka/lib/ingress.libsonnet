local routes = import '../../http/cluster-routes.json';

function(id)
  local route = routes[id];
  {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'Ingress',
    metadata: {
      name: id,
      namespace: route.namespace,
      annotations: { 'traefik.ingress.kubernetes.io/router.entrypoints': 'http' },
    },
    spec: {
      ingressClassName: 'kosmos',
      rules: [
        {
          host: host,
          http: { paths: [{
            path: '/',
            pathType: 'Prefix',
            backend: { service: { name: route.service, port: { number: route.port } } },
          }] },
        }
        for host in route.hosts
      ],
    },
  }
