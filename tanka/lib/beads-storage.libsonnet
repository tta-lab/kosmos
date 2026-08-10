local labels = {
  'app.kubernetes.io/name': 'beads',
  'app.kubernetes.io/part-of': 'kosmos-beads',
};

{
  beadsPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-beads',
      labels: labels,
    },
    spec: {
      capacity: { storage: '20Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/beads',
        type: 'Directory',
      },
    },
  },
  beadsPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'beads-data',
      namespace: 'beads',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-beads',
      resources: { requests: { storage: '20Gi' } },
    },
  },
}
