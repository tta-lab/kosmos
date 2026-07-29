local labels = {
  'app.kubernetes.io/name': 'anki-sync-server',
  'app.kubernetes.io/part-of': 'kosmos-anki',
};

{
  ankiPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-anki',
      labels: labels,
    },
    spec: {
      capacity: { storage: '10Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/anki',
        type: 'Directory',
      },
    },
  },
  ankiPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'anki-data',
      namespace: 'anki',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-anki',
      resources: { requests: { storage: '10Gi' } },
    },
  },
}
