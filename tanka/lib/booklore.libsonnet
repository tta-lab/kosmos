local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': 'kosmos-ebooks-evaluation',
};

local appLabels = labels('booklore');
local dbLabels = labels('booklore-mariadb');

{
  bookloreService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'booklore',
      namespace: 'ebooks',
      labels: appLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: appLabels,
      ports: [{ name: 'http', port: 6060, targetPort: 'http' }],
    },
  },
  bookloreDatabaseService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'booklore-mariadb',
      namespace: 'ebooks',
      labels: dbLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: dbLabels,
      ports: [{ name: 'mysql', port: 3306, targetPort: 'mysql' }],
    },
  },
  bookloreDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'booklore',
      namespace: 'ebooks',
      labels: appLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: appLabels },
      template: {
        metadata: { labels: appLabels },
        spec: {
          containers: [{
            name: 'booklore',
            image: 'ghcr.io/booklore-app/booklore:v2.3.1@sha256:d3d3af34bc2cc44349178535ce19e86049968fba2e7d2acf965f770bf37bad01',
            ports: [{ name: 'http', containerPort: 6060 }],
            env: [
              { name: 'USER_ID', value: '1000' },
              { name: 'GROUP_ID', value: '1000' },
              { name: 'TZ', value: 'Asia/Taipei' },
              { name: 'BOOKLORE_PORT', value: '6060' },
              { name: 'DATABASE_URL', value: 'jdbc:mariadb://booklore-mariadb:3306/booklore' },
              { name: 'DATABASE_USERNAME', value: 'booklore' },
              { name: 'DATABASE_PASSWORD', valueFrom: { secretKeyRef: { name: 'booklore-env', key: 'MARIADB_PASSWORD' } } },
              { name: 'DISK_TYPE', value: 'LOCAL' },
            ],
            readinessProbe: {
              httpGet: { path: '/api/v1/healthcheck', port: 'http' },
              initialDelaySeconds: 30,
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 12,
            },
            resources: {
              requests: { cpu: '100m', memory: '512Mi' },
              limits: { cpu: '2', memory: '2Gi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/app/data', subPath: 'data' },
              { name: 'data', mountPath: '/books', subPath: 'books' },
              { name: 'data', mountPath: '/bookdrop', subPath: 'bookdrop' },
            ],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'booklore-data' } }],
        },
      },
    },
  },
  bookloreDatabase: {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: 'booklore-mariadb',
      namespace: 'ebooks',
      labels: dbLabels,
    },
    spec: {
      serviceName: 'booklore-mariadb',
      replicas: 1,
      selector: { matchLabels: dbLabels },
      template: {
        metadata: { labels: dbLabels },
        spec: {
          securityContext: { fsGroup: 999 },
          containers: [{
            name: 'mariadb',
            image: 'mariadb:11.4.5@sha256:49117dcc565cf51aa57ac5fca59ab31213402ff0eae6ffc13c46a37b938f7e4b',
            ports: [{ name: 'mysql', containerPort: 3306 }],
            env: [
              { name: 'MARIADB_DATABASE', value: 'booklore' },
              { name: 'MARIADB_USER', value: 'booklore' },
              { name: 'MARIADB_PASSWORD', valueFrom: { secretKeyRef: { name: 'booklore-env', key: 'MARIADB_PASSWORD' } } },
              { name: 'MARIADB_ROOT_PASSWORD', valueFrom: { secretKeyRef: { name: 'booklore-env', key: 'MARIADB_ROOT_PASSWORD' } } },
            ],
            readinessProbe: {
              exec: { command: ['healthcheck.sh', '--connect', '--innodb_initialized'] },
              initialDelaySeconds: 10,
              periodSeconds: 5,
              timeoutSeconds: 5,
              failureThreshold: 12,
            },
            resources: {
              requests: { cpu: '50m', memory: '256Mi' },
              limits: { cpu: '1', memory: '1Gi' },
            },
            volumeMounts: [{ name: 'data', mountPath: '/var/lib/mysql' }],
          }],
          volumes: [{ name: 'data', persistentVolumeClaim: { claimName: 'booklore-db' } }],
        },
      },
    },
  },
}
