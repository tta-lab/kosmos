local storage = import '../../lib/beads-storage.libsonnet';
local beads = import '../../lib/beads.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'beads',
    },
  },
} + storage + beads
