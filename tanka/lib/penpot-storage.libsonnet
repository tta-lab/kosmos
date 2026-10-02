local volume(name, size) = {
  ['%sPv' % name]: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: { name: 'kosmos-penpot-' + name },
    spec: {
      capacity: { storage: size },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/penpot/' + name,
        type: 'Directory',
      },
    },
  },
  ['%sPvc' % name]: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: { name: 'penpot-' + name, namespace: 'penpot' },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-penpot-' + name,
      resources: { requests: { storage: size } },
    },
  },
};

volume('postgres-data', '10Gi') + volume('assets', '20Gi')
