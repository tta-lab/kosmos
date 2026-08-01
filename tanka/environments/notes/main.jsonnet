local memos = import '../../lib/memos.libsonnet';
local storage = import '../../lib/notes-storage.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'notes',
    },
  },
} + storage + memos
