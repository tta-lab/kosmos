local storage = import '../../lib/codex-bridge-storage.libsonnet';
local bridge = import '../../lib/codex-bridge.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'codex-bridge',
    },
  },
} + storage + bridge
