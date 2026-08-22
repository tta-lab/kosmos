local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-cloudreve',
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
        // Directory, rather than DirectoryOrCreate, makes an unavailable data
        // disk leave Pods pending instead of writing to the WSL root disk.
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
      namespace: 'cloudreve',
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

local root = '/mnt/kosmos-cloudreve/cloudreve';

volume('cloudreve-data', 'cloudreve-data', root + '/data', '1Ti') +
volume('cloudreve-postgres', 'cloudreve-postgres', root + '/postgres', '20Gi')
