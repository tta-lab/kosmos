local mountPoint = '/mnt/kosmos-cloudreve';
local diskUuid = '441ba8bb-d21b-40e4-a921-ef5553e07ff3';

{
  readyVolume: {
    name: 'micron-storage-ready',
    hostPath: {
      path: mountPoint,
      type: 'Directory',
    },
  },
  waitForReady: {
    name: 'wait-for-micron-storage',
    image: 'busybox:1.37.0',
    command: [
      'sh',
      '-ec',
      'until [ "$(cat /storage/.kosmos-storage-ready 2>/dev/null || true)" = "' + diskUuid + '" ]; do sleep 2; done',
    ],
    securityContext: {
      allowPrivilegeEscalation: false,
      runAsUser: 1000,
      runAsGroup: 100,
      runAsNonRoot: true,
      capabilities: { drop: ['ALL'] },
      seccompProfile: { type: 'RuntimeDefault' },
    },
    volumeMounts: [{ name: 'micron-storage-ready', mountPath: '/storage', readOnly: true }],
  },
}
