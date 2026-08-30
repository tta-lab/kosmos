local labels = {
  'app.kubernetes.io/name': 'hindsight-postgres',
  'app.kubernetes.io/part-of': 'kosmos-hindsight',
};

{
  hindsightPostgresPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-hindsight-postgres',
      labels: labels,
    },
    spec: {
      capacity: { storage: '20Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/hindsight-postgres',
        type: 'Directory',
      },
    },
  },
  hindsightPostgresPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'hindsight-postgres-data',
      namespace: 'hindsight',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-hindsight-postgres',
      resources: { requests: { storage: '20Gi' } },
    },
  },
}
