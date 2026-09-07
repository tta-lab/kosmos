local labels = {
  'app.kubernetes.io/name': 'clipcascade',
  'app.kubernetes.io/part-of': 'kosmos-clipcascade',
};

{
  clipcascadePv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-clipcascade',
      labels: labels,
    },
    spec: {
      capacity: { storage: '5Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/clipcascade',
        type: 'Directory',
      },
    },
  },
  clipcascadePvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'clipcascade-data',
      namespace: 'clipcascade',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-clipcascade',
      resources: { requests: { storage: '5Gi' } },
    },
  },
}
