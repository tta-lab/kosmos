local storage = import '../../lib/penpot-storage.libsonnet';
local penpot = import '../../lib/penpot.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: { name: 'penpot' },
  },
} + penpot + storage
