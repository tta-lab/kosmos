local labels = {
  'app.kubernetes.io/name': 'meilisearch',
  'app.kubernetes.io/part-of': 'kosmos-meilisearch',
};

{
  dataPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-meilisearch-data',
      labels: labels,
    },
    spec: {
      capacity: { storage: '10Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/meilisearch/data',
        type: 'Directory',
      },
    },
  },
  dataPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'meilisearch-data',
      namespace: 'meilisearch',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-meilisearch-data',
      resources: { requests: { storage: '10Gi' } },
    },
  },
}
