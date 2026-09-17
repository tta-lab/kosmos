local storage = import '../../lib/meilisearch-storage.libsonnet';
local meilisearch = import '../../lib/meilisearch.libsonnet';

{
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'meilisearch',
    },
  },
} + storage + meilisearch
