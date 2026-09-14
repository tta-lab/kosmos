local navidrome = import '../../lib/navidrome.libsonnet';
local storage = import '../../lib/navidrome-storage.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'navidrome',
    },
  },
} + storage + navidrome
