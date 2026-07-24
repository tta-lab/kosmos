local storage = import '../../lib/ente-storage.libsonnet';
local garage = import '../../lib/garage.libsonnet';
local ente = import '../../lib/ente.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'photos',
    },
  },
} + storage + garage + ente
