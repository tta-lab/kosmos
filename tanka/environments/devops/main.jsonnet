local gateway = import '../../lib/gateway.libsonnet';
local dagger = import '../../lib/dagger.libsonnet';
{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: { name: 'devops' },
  },
} + gateway + dagger
