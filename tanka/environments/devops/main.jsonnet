local storage = import '../../lib/storage.libsonnet';
local gateway = import '../../lib/gateway.libsonnet';
local forgejo = import '../../lib/forgejo.libsonnet';
local woodpecker = import '../../lib/woodpecker.libsonnet';
local dagger = import '../../lib/dagger.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'devops',
    },
  },
} + storage + gateway + forgejo + woodpecker + dagger
