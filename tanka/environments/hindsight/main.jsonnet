local storage = import '../../lib/hindsight-storage.libsonnet';
local hindsight = import '../../lib/hindsight.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'hindsight',
    },
  },
} + storage + hindsight
