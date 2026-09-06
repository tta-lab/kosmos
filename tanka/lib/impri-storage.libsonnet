local labels = {
  'app.kubernetes.io/name': 'impri-server',
  'app.kubernetes.io/part-of': 'kosmos-impri',
};

{
  impriPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-impri',
      labels: labels,
    },
    spec: {
      capacity: { storage: '5Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/impri',
        type: 'Directory',
      },
    },
  },
  impriPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'impri-data',
      namespace: 'impri',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-impri',
      resources: { requests: { storage: '5Gi' } },
    },
  },
}
