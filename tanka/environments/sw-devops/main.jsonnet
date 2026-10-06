function(enabled='false', forgejoR2BackupEnabled='false', forgejoStorageClass='zfs-local')
  local forgejo = import '../../lib/forgejo.libsonnet';
  local woodpecker = import '../../lib/woodpecker.libsonnet';
  local active = enabled == 'true';
  local namespace = 'seafarer';
  local address = '192.168.6.186';
  local forgeUrl = 'https://' + address + ':8086/';
  local ciUrl = 'https://' + address + ':8087';
  local proxyUrl = 'http://10.42.0.1:17891';
  local noProxy = 'localhost,127.0.0.1,::1,10.42.0.0/16,10.43.0.0/16,.svc,.cluster.local,forgejo,woodpecker,woodpecker-postgres,' + address;
  local env(values) = [{ name: key, value: values[key] } for key in std.objectFields(values)];
  local backup = (import '../../lib/forgejo-backup.libsonnet')(env({
    HTTP_PROXY: proxyUrl,
    HTTPS_PROXY: proxyUrl,
    NO_PROXY: noProxy,
    http_proxy: proxyUrl,
    https_proxy: proxyUrl,
    no_proxy: noProxy,
  }));
  local replaceEnv(original, values) = [e for e in original if !std.objectHas(values, e.name)] + env(values);
  local proxyEnv = {
    HTTP_PROXY: proxyUrl,
    HTTPS_PROXY: proxyUrl,
    NO_PROXY: noProxy,
    http_proxy: proxyUrl,
    https_proxy: proxyUrl,
    no_proxy: noProxy,
    SSL_CERT_FILE: '/etc/sw-trust/ca-bundle.crt',
  };
  local trustMount = { name: 'trust', mountPath: '/etc/sw-trust', readOnly: true };
  local trustVolumes = [
    { name: 'trust', emptyDir: {} },
    { name: 'sw-ca', configMap: { name: 'sw-devops-ca' } },
  ];
  local trustInit = {
    name: 'prepare-ca',
    image: 'codeberg.org/forgejo/forgejo:15.0.3-rootless',
    command: ['/bin/sh', '-ec', 'cat /etc/ssl/certs/ca-certificates.crt /sw-ca/ca.crt > /trust/ca-bundle.crt'],
    securityContext: { runAsUser: 0 },
    volumeMounts: [
      { name: 'trust', mountPath: '/trust' },
      { name: 'sw-ca', mountPath: '/sw-ca', readOnly: true },
    ],
  };
  local namespaced(resource) = resource { metadata+: { namespace: namespace } };
  local pvc(name, size, storageClass='zfs-local') = {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: { name: name, namespace: namespace },
    spec: {
      storageClassName: storageClass,
      accessModes: ['ReadWriteOnce'],
      resources: { requests: { storage: size } },
    },
  };
  local forgeValues = proxyEnv {
    FORGEJO__server__DOMAIN: address,
    FORGEJO__server__ROOT_URL: forgeUrl,
    FORGEJO__session__COOKIE_SECURE: 'true',
    FORGEJO__webhook__ALLOWED_HOST_LIST: 'external,woodpecker',
  };
  local forgePod = forgejo.forgejoDeployment.spec.template.spec;
  local serverPod = woodpecker.woodpeckerServer.spec.template.spec;
  local agentPod = woodpecker.woodpeckerAgent.spec.template.spec;
  local pipelineEnv = std.join(',', [
    '_EXPERIMENTAL_DAGGER_RUNNER_HOST:tcp://10.42.0.1:18081',
    'PLUGIN_CUSTOM_SSL_URL:https://raw.githubusercontent.com/tta-lab/kosmos/592591f87b6beb9d6c901a0812b5682367718882/certs/seafarer-root-ca.pem',
  ]);
  local workloads = {
    forgejoDeployment: namespaced(forgejo.forgejoDeployment) + {
      spec+: {
        replicas: if active then 1 else 0,
        template+: { spec+: {
          initContainers: [trustInit] + [c {
            env: replaceEnv(c.env, forgeValues),
            volumeMounts: c.volumeMounts + [trustMount],
          } for c in forgePod.initContainers],
          containers: [c {
            env: replaceEnv(c.env, forgeValues),
            volumeMounts: c.volumeMounts + [trustMount],
          } for c in forgePod.containers],
          volumes: forgePod.volumes + trustVolumes,
        } },
      },
    },
    forgejoService: namespaced(forgejo.forgejoService),
    woodpeckerServer: namespaced(woodpecker.woodpeckerServer) + {
      spec+: {
        replicas: if active then 1 else 0,
        template+: { spec+: {
          initContainers: [trustInit],
          volumes: trustVolumes,
          containers: [c {
            env: replaceEnv(c.env, proxyEnv {
              WOODPECKER_HOST: ciUrl,
              WOODPECKER_FORGEJO_URL: 'http://forgejo:3000',
              WOODPECKER_EXPERT_FORGE_OAUTH_HOST: std.rstripChars(forgeUrl, '/'),
              WOODPECKER_EXPERT_WEBHOOK_HOST: 'http://woodpecker:8000',
              WOODPECKER_ENVIRONMENT: pipelineEnv,
              // Dedicated string flags preserve commas; ENVIRONMENT is a slice.
              WOODPECKER_BACKEND_HTTP_PROXY: proxyUrl,
              WOODPECKER_BACKEND_HTTPS_PROXY: proxyUrl,
              WOODPECKER_BACKEND_NO_PROXY: noProxy,
            }),
            volumeMounts: [trustMount],
          } for c in serverPod.containers],
        } },
      },
    },
    woodpeckerAgent: namespaced(woodpecker.woodpeckerAgent) + {
      spec+: {
        replicas: if active then 2 else 0,
        template+: { spec+: {
          initContainers: [trustInit] + agentPod.initContainers,
          volumes: trustVolumes,
          containers: [c {
            env: replaceEnv(c.env, proxyEnv {
              WOODPECKER_BACKEND_K8S_NAMESPACE: namespace,
              WOODPECKER_BACKEND_K8S_STORAGE_CLASS: 'zfs-local',
              WOODPECKER_BACKEND_K8S_VOLUME_SIZE: '1Gi',
            }),
            volumeMounts: [trustMount],
          } for c in agentPod.containers],
        } },
      },
    },
  } + {
    [key]: namespaced(woodpecker[key])
    for key in [
      'woodpeckerService',
      'woodpeckerPostgresService',
      'woodpeckerPostgres',
      'woodpeckerAgentServiceAccount',
      'woodpeckerAgentRole',
      'woodpeckerAgentRoleBinding',
    ]
  };
  (workloads + (if forgejoR2BackupEnabled == 'true' then {
                  [key]: namespaced(backup[key])
                  for key in std.objectFields(backup)
                } else {})) {
    // Bind the ServiceAccount in the SW namespace rather than the WSL one.
    woodpeckerAgentRoleBinding+: {
      subjects: [{ kind: 'ServiceAccount', name: 'woodpecker-agent', namespace: namespace }],
    },
    forgejoPvc: pvc('forgejo-data', '100Gi', forgejoStorageClass),
    woodpeckerPostgresPvc: pvc('woodpecker-postgres', '10Gi'),
    ca: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: { name: 'sw-devops-ca', namespace: namespace },
      data: { 'ca.crt': importstr '../../../certs/seafarer-root-ca.pem' },
    },
    edgeConfig: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: { name: 'sw-devops-edge', namespace: namespace },
      data: { Caddyfile: |||
        {
          auto_https off
          admin off
        }
        https://:8086 {
          tls /tls/tls.crt /tls/tls.key
          reverse_proxy forgejo:3000
        }
        https://:8087 {
          tls /tls/tls.crt /tls/tls.key
          reverse_proxy woodpecker:8000
        }
      ||| },
    },
    edge: {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'sw-devops-edge', namespace: namespace },
      spec: {
        replicas: 1,
        strategy: { type: 'Recreate' },
        selector: { matchLabels: { app: 'sw-devops-edge' } },
        template: {
          metadata: { labels: { app: 'sw-devops-edge' } },
          spec: {
            containers: [{
              name: 'caddy',
              image: 'caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d',
              command: ['caddy'],
              args: ['run', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile'],
              ports: [
                { name: 'forgejo', containerPort: 8086, hostPort: 8086, hostIP: address },
                { name: 'woodpecker', containerPort: 8087, hostPort: 8087, hostIP: address },
              ],
              resources: { requests: { cpu: '10m', memory: '32Mi' }, limits: { memory: '128Mi' } },
              volumeMounts: [
                { name: 'config', mountPath: '/etc/caddy', readOnly: true },
                { name: 'tls', mountPath: '/tls', readOnly: true },
                { name: 'data', mountPath: '/data' },
                { name: 'runtime', mountPath: '/config' },
              ],
            }],
            volumes: [
              { name: 'config', configMap: { name: 'sw-devops-edge' } },
              { name: 'tls', secret: { secretName: 'seafarer-edge-tls' } },
              { name: 'data', emptyDir: {} },
              { name: 'runtime', emptyDir: {} },
            ],
          },
        },
      },
    },
    keposPodBridge: {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: { name: 'sw-kepos-pod-bridge', namespace: namespace },
      spec: {
        replicas: 1,
        strategy: { type: 'Recreate' },
        selector: { matchLabels: { app: 'sw-kepos-pod-bridge' } },
        template: {
          metadata: { labels: { app: 'sw-kepos-pod-bridge' } },
          spec: {
            hostNetwork: true,
            dnsPolicy: 'ClusterFirstWithHostNet',
            containers: [
              {
                name: entry[0],
                image: 'alpine/socat:1.8.0.3@sha256:beb4a68d9e4fe6b0f21ea774a0fde6c31f580dde6368939ed70100c5385b015e',
                args: ['TCP-LISTEN:' + std.toString(entry[1]) + ',bind=10.42.0.1,fork,reuseaddr', 'TCP:127.0.0.1:' + std.toString(entry[2])],
                resources: { requests: { cpu: '5m', memory: '8Mi' }, limits: { memory: '64Mi' } },
                securityContext: { runAsUser: 65534, allowPrivilegeEscalation: false, capabilities: { drop: ['ALL'] } },
              }
              for entry in [['mihomo', 17891, 17890], ['dagger', 18081, 18080]]
            ],
          },
        },
      },
    },
  }
  + (if forgejoStorageClass == 'zfs-local-forgejo-shared' then {
       forgejoSharedStorageClass: {
         apiVersion: 'storage.k8s.io/v1',
         kind: 'StorageClass',
         metadata: { name: 'zfs-local-forgejo-shared' },
         provisioner: 'zfs.csi.openebs.io',
         allowVolumeExpansion: true,
         volumeBindingMode: 'WaitForFirstConsumer',
         reclaimPolicy: 'Retain',
         parameters: {
           compression: 'lz4',
           fstype: 'zfs',
           poolname: 'tank/k8s',
           recordsize: '128k',
           shared: 'yes',
         },
       },
     } else {})
