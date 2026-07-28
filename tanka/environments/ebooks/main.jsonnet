local bookorbit = import '../../lib/bookorbit.libsonnet';
local storage = import '../../lib/ebooks-storage.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'ebooks',
    },
  },
} + storage + bookorbit
