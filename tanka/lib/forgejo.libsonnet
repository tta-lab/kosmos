local labels = {
  'app.kubernetes.io/name': 'forgejo',
  'app.kubernetes.io/part-of': 'kosmos-devops',
};
local forgejoEnv = [
  { name: 'FORGEJO_WORK_DIR', value: '/var/lib/gitea' },
  { name: 'FORGEJO____WORK_PATH', value: '/var/lib/gitea' },
  { name: 'FORGEJO____RUN_USER', value: 'git' },
  { name: 'FORGEJO__server__DOMAIN', value: 'forgejo.localhost' },
  { name: 'FORGEJO__server__ROOT_URL', value: 'http://forgejo.localhost:17480/' },
  { name: 'FORGEJO__server__HTTP_ADDR', value: '0.0.0.0' },
  { name: 'FORGEJO__server__HTTP_PORT', value: '3000' },
  { name: 'FORGEJO__server__DISABLE_SSH', value: 'true' },
  { name: 'FORGEJO__server__LFS_START_SERVER', value: 'true' },
  { name: 'FORGEJO__server__STATIC_ROOT_PATH', value: '/app/gitea' },
  { name: 'FORGEJO__database__DB_TYPE', value: 'sqlite3' },
  { name: 'FORGEJO__database__PATH', value: '/var/lib/gitea/data/forgejo.db' },
  { name: 'FORGEJO__repository__ROOT', value: '/var/lib/gitea/repositories' },
  { name: 'FORGEJO__lfs__PATH', value: '/var/lib/gitea/data/lfs' },
  { name: 'FORGEJO__log__ROOT_PATH', value: '/var/lib/gitea/log' },
  { name: 'FORGEJO__packages__ENABLED', value: 'true' },
  { name: 'FORGEJO__service__DISABLE_REGISTRATION', value: 'true' },
  { name: 'FORGEJO__service__REQUIRE_SIGNIN_VIEW', value: 'true' },
  { name: 'FORGEJO__session__COOKIE_SECURE', value: 'false' },
  { name: 'FORGEJO__actions__ENABLED', value: 'false' },
  { name: 'FORGEJO__webhook__ALLOWED_HOST_LIST', value: 'external,woodpecker' },
];
local dataMount = [{ name: 'data', mountPath: '/var/lib/gitea' }];

{
  forgejoDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'forgejo',
      namespace: 'devops',
      labels: labels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          securityContext: {
            runAsUser: 1000,
            runAsGroup: 1000,
            fsGroup: 1000,
            fsGroupChangePolicy: 'OnRootMismatch',
          },
          initContainers: [{
            name: 'regenerate-hooks',
            image: 'codeberg.org/forgejo/forgejo:15.0.3-rootless',
            args: [
              '/bin/sh',
              '-ec',
              'forgejo migrate && forgejo admin regenerate hooks',
            ],
            env: forgejoEnv,
            volumeMounts: dataMount,
          }],
          containers: [{
            name: 'forgejo',
            image: 'codeberg.org/forgejo/forgejo:15.0.3-rootless',
            env: forgejoEnv,
            ports: [{ name: 'http', containerPort: 3000 }],
            readinessProbe: {
              httpGet: { path: '/api/healthz', port: 'http' },
              initialDelaySeconds: 5,
              periodSeconds: 5,
            },
            resources: {
              requests: { cpu: '100m', memory: '256Mi' },
              limits: { cpu: '2', memory: '2Gi' },
            },
            volumeMounts: dataMount,
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'forgejo-data' } }],
        },
      },
    },
  },
  forgejoService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'forgejo',
      namespace: 'devops',
      labels: labels,
    },
    spec: {
      selector: labels,
      ports: [{ name: 'http', port: 3000, targetPort: 'http' }],
    },
  },
}
