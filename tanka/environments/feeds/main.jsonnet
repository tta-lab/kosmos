local miniflux = import '../../lib/miniflux.libsonnet';
local storage = import '../../lib/feeds-storage.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'feeds',
    },
  },
} + storage + miniflux
