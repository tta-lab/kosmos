local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-ebooks-evaluation',
};

local volume(name, claimName, path, size) = {
  [name + 'Pv']: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: { name: 'kosmos-' + name },
    spec: {
      capacity: { storage: size },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: path,
        type: 'Directory',
      },
    },
  },
  [name + 'Pvc']: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: claimName,
      namespace: 'ebooks',
      labels: labels(name),
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-' + name,
      resources: { requests: { storage: size } },
    },
  },
};

volume('bookorbit', 'bookorbit-data', '/var/lib/kosmos-k3s/ebooks/bookorbit', '20Gi') +
volume('bookorbit-db', 'bookorbit-db', '/var/lib/kosmos-k3s/ebooks/bookorbit-db', '5Gi')
