local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-photos',
};

{
  postgresPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-ente-postgres',
      labels: labels('postgres'),
    },
    spec: {
      capacity: { storage: '10Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/ente/postgres',
        type: 'Directory',
      },
    },
  },
  postgresPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'postgres-data',
      namespace: 'photos',
      labels: labels('postgres'),
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-ente-postgres',
      resources: { requests: { storage: '10Gi' } },
    },
  },
  garagePv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-ente-garage',
      labels: labels('garage'),
    },
    spec: {
      capacity: { storage: '500Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/ente/garage',
        type: 'Directory',
      },
    },
  },
  garagePvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'garage-data',
      namespace: 'photos',
      labels: labels('garage'),
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-ente-garage',
      resources: { requests: { storage: '500Gi' } },
    },
  },
}
