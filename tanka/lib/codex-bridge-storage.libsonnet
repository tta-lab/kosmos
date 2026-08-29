local labels = {
  'app.kubernetes.io/name': 'codex-bridge',
  'app.kubernetes.io/part-of': 'kosmos-codex-bridge',
};

{
  codexBridgePv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-codex-bridge',
      labels: labels,
    },
    spec: {
      capacity: { storage: '64Mi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/codex-bridge',
        type: 'Directory',
      },
    },
  },
  codexBridgePvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'codex-bridge-state',
      namespace: 'codex-bridge',
      labels: labels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-codex-bridge',
      resources: { requests: { storage: '64Mi' } },
    },
  },
}
