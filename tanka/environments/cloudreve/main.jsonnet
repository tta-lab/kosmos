local storage = import '../../lib/cloudreve-storage.libsonnet';
local cloudreve = import '../../lib/cloudreve.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'cloudreve',
    },
  },
} + storage + cloudreve
