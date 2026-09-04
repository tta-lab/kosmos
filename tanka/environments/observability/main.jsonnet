local observability = import '../../lib/observability.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'observability',
    },
  },
} + observability
