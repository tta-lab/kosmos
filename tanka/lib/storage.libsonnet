local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-devops',
};

{
  forgejoPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: { name: 'kosmos-forgejo' },
    spec: {
      capacity: { storage: '20Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/forgejo',
        type: 'Directory',
      },
    },
  },
  forgejoPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'forgejo-data',
      namespace: 'devops',
      labels: labels('forgejo'),
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-forgejo',
      resources: { requests: { storage: '20Gi' } },
    },
  },
  woodpeckerPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: { name: 'kosmos-woodpecker' },
    spec: {
      capacity: { storage: '5Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/woodpecker',
        type: 'Directory',
      },
    },
  },
  woodpeckerPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'woodpecker-data',
      namespace: 'devops',
      labels: labels('woodpecker'),
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-woodpecker',
      resources: { requests: { storage: '5Gi' } },
    },
  },
}
