local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-navidrome',
};

local volume(name, claimName, path, size) = {
  [name + 'Pv']: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-' + name,
      labels: labels(name),
    },
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
      namespace: 'navidrome',
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

volume('navidrome-data', 'navidrome-data', '/mnt/kosmos-cloudreve/navidrome/data', '5Gi')
+ volume('navidrome-cache', 'navidrome-cache', '/mnt/kosmos-cloudreve/navidrome/cache', '5Gi')
+ volume('navidrome-music', 'navidrome-music', '/mnt/kosmos-cloudreve/navidrome/music', '500Gi')
