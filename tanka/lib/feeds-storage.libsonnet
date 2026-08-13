local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-feeds',
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
      namespace: 'feeds',
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

volume('miniflux-db', 'miniflux-db', '/var/lib/kosmos-k3s/feeds/miniflux-db', '5Gi')
