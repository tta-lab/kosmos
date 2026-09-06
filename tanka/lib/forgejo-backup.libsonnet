local labels = {
  'app.kubernetes.io/name': 'forgejo-source-backup',
  'app.kubernetes.io/part-of': 'kosmos-devops',
};

local resticImage = 'docker.io/mazzolino/restic:1.8.2@sha256:685293a0bc77eb054b74b207561e7d2eda6cfc910984c5a93db8f253055118e2';
local sqliteImage = 'docker.io/keinos/sqlite3:3.53.4@sha256:6addaf450aea7e098e7d6f059d43501c317ec70494c1ace3cc94bfe1631cbfa5';
local backupScript = importstr '../../scripts/backup-forgejo';
local secretEnv(key) = {
  name: key,
  valueFrom: {
    secretKeyRef: {
      name: 'forgejo-r2-backup',
      key: key,
      optional: false,
    },
  },
};

{
  forgejoBackupScript: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'forgejo-source-backup',
      namespace: 'devops',
      labels: labels,
    },
    data: {
      'backup-forgejo': backupScript,
    },
  },
  forgejoSourceBackup: {
    apiVersion: 'batch/v1',
    kind: 'CronJob',
    metadata: {
      name: 'forgejo-source-backup',
      namespace: 'devops',
      labels: labels,
    },
    spec: {
      // Run at 04:00 Taipei time, independently of the node's local timezone.
      schedule: '0 4 * * *',
      timeZone: 'Asia/Taipei',
      concurrencyPolicy: 'Forbid',
      startingDeadlineSeconds: 3600,
      successfulJobsHistoryLimit: 3,
      failedJobsHistoryLimit: 3,
      jobTemplate: {
        metadata: { labels: labels },
        spec: {
          activeDeadlineSeconds: 3600,
          backoffLimit: 0,
          ttlSecondsAfterFinished: 86400,
          template: {
            metadata: { labels: labels },
            spec: {
              automountServiceAccountToken: false,
              restartPolicy: 'Never',
              securityContext: {
                runAsNonRoot: true,
                runAsUser: 1000,
                runAsGroup: 1000,
                fsGroup: 1000,
                fsGroupChangePolicy: 'OnRootMismatch',
                seccompProfile: { type: 'RuntimeDefault' },
              },
              initContainers: [{
                name: 'stage-sqlite',
                image: sqliteImage,
                imagePullPolicy: 'IfNotPresent',
                command: ['/bin/sh', '-ec'],
                args: [
                  'mkdir -p /staging/bin && cp /usr/bin/sqlite3 /staging/bin/sqlite3 && chmod 0755 /staging/bin/sqlite3',
                ],
                securityContext: {
                  allowPrivilegeEscalation: false,
                  capabilities: { drop: ['ALL'] },
                  readOnlyRootFilesystem: true,
                },
                resources: {
                  requests: { cpu: '5m', memory: '8Mi' },
                  limits: { cpu: '50m', memory: '32Mi' },
                },
                volumeMounts: [{ name: 'staging', mountPath: '/staging' }],
              }],
              containers: [{
                name: 'backup',
                image: resticImage,
                imagePullPolicy: 'IfNotPresent',
                command: ['/bin/bash', '/opt/backup/backup-forgejo'],
                env: [
                  secretEnv('AWS_ACCESS_KEY_ID'),
                  secretEnv('AWS_SECRET_ACCESS_KEY'),
                  secretEnv('RESTIC_PASSWORD'),
                  secretEnv('RESTIC_REPOSITORY'),
                  { name: 'AWS_DEFAULT_REGION', value: 'auto' },
                  { name: 'AWS_EC2_METADATA_DISABLED', value: 'true' },
                  { name: 'RESTIC_CACHE_DIR', value: '/staging/restic-cache' },
                  { name: 'SQLITE3_BIN', value: '/staging/bin/sqlite3' },
                  { name: 'FORGEJO_DATA_ROOT', value: '/var/lib/gitea' },
                  { name: 'FORGEJO_BACKUP_STAGING', value: '/staging' },
                  { name: 'HOME', value: '/staging/home' },
                  {
                    name: 'PATH',
                    value: '/staging/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
                  },
                ],
                securityContext: {
                  allowPrivilegeEscalation: false,
                  capabilities: { drop: ['ALL'] },
                  readOnlyRootFilesystem: true,
                },
                resources: {
                  requests: { cpu: '100m', memory: '256Mi' },
                  limits: { cpu: '1', memory: '1Gi' },
                },
                volumeMounts: [
                  { name: 'forgejo-data', mountPath: '/var/lib/gitea', readOnly: true },
                  { name: 'staging', mountPath: '/staging' },
                  { name: 'tmp', mountPath: '/tmp' },
                  {
                    name: 'backup-script',
                    mountPath: '/opt/backup/backup-forgejo',
                    subPath: 'backup-forgejo',
                    readOnly: true,
                  },
                ],
              }],
              volumes: [
                {
                  name: 'forgejo-data',
                  persistentVolumeClaim: {
                    claimName: 'forgejo-data',
                    readOnly: true,
                  },
                },
                { name: 'staging', emptyDir: { sizeLimit: '512Mi' } },
                { name: 'tmp', emptyDir: { sizeLimit: '128Mi' } },
                {
                  name: 'backup-script',
                  configMap: {
                    name: 'forgejo-source-backup',
                    defaultMode: 365,
                  },
                },
              ],
            },
          },
        },
      },
    },
  },
}
