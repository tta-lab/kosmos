local labels = {
  'app.kubernetes.io/name': 'dagger',
  'app.kubernetes.io/part-of': 'kosmos-devops',
};
local topology = import '../../modules/wsl/proxy-topology.json';

{
  daggerService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'dagger',
      namespace: 'devops',
      labels: labels,
    },
    spec: {
      ports: [{ name: 'grpc', port: 8080, targetPort: 8080 }],
    },
  },
  daggerEndpointSlice: {
    apiVersion: 'discovery.k8s.io/v1',
    kind: 'EndpointSlice',
    metadata: {
      name: 'dagger-n5',
      namespace: 'devops',
      labels: {
        'kubernetes.io/service-name': 'dagger',
        'endpointslice.kubernetes.io/managed-by': 'kosmos',
      },
    },
    addressType: 'IPv4',
    ports: [{ name: 'grpc', protocol: 'TCP', port: 8080 }],
    endpoints: [{ addresses: [topology.podProxyHost] }],
  },
}
