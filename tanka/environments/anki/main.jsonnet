local anki = import '../../lib/anki.libsonnet';
local storage = import '../../lib/anki-storage.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'anki',
    },
  },
} + storage + anki
