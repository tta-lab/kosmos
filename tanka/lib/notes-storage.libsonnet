local labels = {
  'app.kubernetes.io/name': 'memos',
  'app.kubernetes.io/part-of': 'kosmos-notes',
};

{
  memosPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: { name: 'kosmos-memos' },
    spec: {
      capacity: { storage: '5Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/notes/memos',
        type: 'Directory',
      },
    },
  },
  memosPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'memos-data',
      namespace: 'notes',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-memos',
      resources: { requests: { storage: '5Gi' } },
    },
  },
}
