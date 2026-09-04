local partOf = 'kosmos-observability';

local labels(name) = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/part-of': partOf,
};

local victoriaLabels = labels('victoria-metrics');
local grafanaLabels = labels('grafana');
local victoriaImage = 'victoriametrics/victoria-metrics:v1.123.0@sha256:e47c14e6bacd79eaa05a032f263dca91a157f1618de65f8f1f1617e44ebd3757';
local grafanaImage = 'grafana/grafana:12.1.1@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d';
local dashboardPath = '/run/current-system/sw/share/kepos/grafana/kepos-publisher-observability.json';

{
  victoriaMetricsScrapeConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'victoria-metrics-scrape',
      namespace: 'observability',
      labels: victoriaLabels,
    },
    data: {
      'prometheus.yml': |||
        global:
          scrape_interval: 15s
        scrape_configs:
          - job_name: kepos-publisher
            metrics_path: /metrics
            static_configs:
              - targets:
                  - 10.255.255.1:9475
      |||,
    },
  },

  victoriaMetricsPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-victoria-metrics',
      labels: victoriaLabels,
    },
    spec: {
      capacity: { storage: '2Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/observability/victoria-metrics',
        type: 'Directory',
      },
    },
  },

  victoriaMetricsPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'victoria-metrics-data',
      namespace: 'observability',
      labels: victoriaLabels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-victoria-metrics',
      resources: { requests: { storage: '2Gi' } },
    },
  },

  victoriaMetricsService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'victoria-metrics',
      namespace: 'observability',
      labels: victoriaLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: victoriaLabels,
      ports: [{ name: 'http', port: 8428, targetPort: 'http' }],
    },
  },

  victoriaMetricsDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'victoria-metrics',
      namespace: 'observability',
      labels: victoriaLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: victoriaLabels },
      template: {
        metadata: { labels: victoriaLabels },
        spec: {
          automountServiceAccountToken: false,
          securityContext: {
            runAsNonRoot: true,
            runAsUser: 65534,
            runAsGroup: 65534,
            fsGroup: 65534,
            seccompProfile: { type: 'RuntimeDefault' },
          },
          containers: [{
            name: 'victoria-metrics',
            image: victoriaImage,
            imagePullPolicy: 'IfNotPresent',
            args: [
              '-httpListenAddr=:8428',
              '-promscrape.config=/etc/victoria-metrics/prometheus.yml',
              '-retentionPeriod=30d',
              '-storageDataPath=/var/lib/victoria-metrics',
              '-storage.minFreeDiskSpaceBytes=256MiB',
            ],
            ports: [{ name: 'http', containerPort: 8428 }],
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
            },
            readinessProbe: {
              httpGet: { path: '/health', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 6,
            },
            livenessProbe: {
              httpGet: { path: '/health', port: 'http' },
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '50m', memory: '256Mi' },
              limits: { cpu: '500m', memory: '512Mi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/var/lib/victoria-metrics' },
              { name: 'scrape-config', mountPath: '/etc/victoria-metrics', readOnly: true },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'victoria-metrics-data' } },
            { name: 'scrape-config', configMap: { name: 'victoria-metrics-scrape' } },
          ],
        },
      },
    },
  },

  grafanaPv: {
    apiVersion: 'v1',
    kind: 'PersistentVolume',
    metadata: {
      name: 'kosmos-grafana',
      labels: grafanaLabels,
    },
    spec: {
      capacity: { storage: '2Gi' },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      storageClassName: 'kosmos-static',
      hostPath: {
        path: '/var/lib/kosmos-k3s/observability/grafana',
        type: 'Directory',
      },
    },
  },

  grafanaPvc: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: 'grafana-data',
      namespace: 'observability',
      labels: grafanaLabels,
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      storageClassName: 'kosmos-static',
      volumeName: 'kosmos-grafana',
      resources: { requests: { storage: '2Gi' } },
    },
  },

  grafanaDatasourceConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-datasources',
      namespace: 'observability',
      labels: grafanaLabels,
    },
    data: {
      'datasources.yaml': |||
        apiVersion: 1
        datasources:
          - name: VictoriaMetrics
            type: prometheus
            uid: victoriametrics
            access: proxy
            url: http://victoria-metrics.observability.svc.cluster.local:8428
            isDefault: true
            editable: false
      |||,
    },
  },

  grafanaDashboardProviderConfig: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-dashboard-provider',
      namespace: 'observability',
      labels: grafanaLabels,
    },
    data: {
      'dashboards.yaml': |||
        apiVersion: 1
        providers:
          - name: Kepos
            orgId: 1
            folder: Kepos
            type: file
            disableDeletion: true
            updateIntervalSeconds: 30
            options:
              path: /var/lib/grafana/dashboards
      |||,
    },
  },

  grafanaService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'grafana',
      namespace: 'observability',
      labels: grafanaLabels,
    },
    spec: {
      type: 'ClusterIP',
      selector: grafanaLabels,
      ports: [{ name: 'http', port: 3000, targetPort: 'http' }],
    },
  },

  grafanaDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'grafana',
      namespace: 'observability',
      labels: grafanaLabels,
    },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: grafanaLabels },
      template: {
        metadata: { labels: grafanaLabels },
        spec: {
          automountServiceAccountToken: false,
          securityContext: {
            runAsNonRoot: true,
            runAsUser: 472,
            runAsGroup: 472,
            fsGroup: 472,
            seccompProfile: { type: 'RuntimeDefault' },
          },
          containers: [{
            name: 'grafana',
            image: grafanaImage,
            imagePullPolicy: 'IfNotPresent',
            env: [
              { name: 'GF_SECURITY_ADMIN_USER', value: 'admin' },
              {
                name: 'GF_SECURITY_ADMIN_PASSWORD',
                valueFrom: {
                  secretKeyRef: {
                    name: 'grafana-admin',
                    key: 'admin-password',
                  },
                },
              },
              { name: 'GF_USERS_ALLOW_SIGN_UP', value: 'false' },
              { name: 'GF_SERVER_DOMAIN', value: 'grafana.localhost' },
              { name: 'GF_SERVER_ROOT_URL', value: 'http://grafana.localhost:17480' },
            ],
            ports: [{ name: 'http', containerPort: 3000 }],
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: ['ALL'] },
            },
            readinessProbe: {
              httpGet: { path: '/api/health', port: 'http' },
              periodSeconds: 10,
              timeoutSeconds: 5,
              failureThreshold: 6,
            },
            livenessProbe: {
              httpGet: { path: '/api/health', port: 'http' },
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3,
            },
            resources: {
              requests: { cpu: '50m', memory: '128Mi' },
              limits: { cpu: '500m', memory: '256Mi' },
            },
            volumeMounts: [
              { name: 'data', mountPath: '/var/lib/grafana' },
              {
                name: 'datasources',
                mountPath: '/etc/grafana/provisioning/datasources/datasources.yaml',
                subPath: 'datasources.yaml',
                readOnly: true,
              },
              {
                name: 'dashboard-provider',
                mountPath: '/etc/grafana/provisioning/dashboards/dashboards.yaml',
                subPath: 'dashboards.yaml',
                readOnly: true,
              },
              {
                name: 'dashboard',
                mountPath: '/var/lib/grafana/dashboards/kepos-publisher-observability.json',
                readOnly: true,
              },
              { name: 'tmp', mountPath: '/tmp' },
            ],
          }],
          volumes: [
            { name: 'data', persistentVolumeClaim: { claimName: 'grafana-data' } },
            { name: 'datasources', configMap: { name: 'grafana-datasources' } },
            { name: 'dashboard-provider', configMap: { name: 'grafana-dashboard-provider' } },
            { name: 'dashboard', hostPath: { path: dashboardPath, type: 'File' } },
            { name: 'tmp', emptyDir: { sizeLimit: '64Mi' } },
          ],
        },
      },
    },
  },
}
