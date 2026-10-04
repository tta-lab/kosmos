local labels = { 'app.kubernetes.io/name': 'cluster-http' };
local read = ['get', 'list', 'watch'];

{
  ingressClass: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'IngressClass',
    metadata: { name: 'kosmos' },
    spec: { controller: 'traefik.io/ingress-controller' },
  },
  ingressAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: { name: 'cluster-http', namespace: 'devops' },
  },
  ingressRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: { name: 'kosmos-cluster-http' },
    rules: [
      { apiGroups: [''], resources: ['services', 'secrets', 'nodes'], verbs: read },
      { apiGroups: ['discovery.k8s.io'], resources: ['endpointslices'], verbs: read },
      { apiGroups: ['networking.k8s.io'], resources: ['ingresses', 'ingressclasses'], verbs: read },
      { apiGroups: ['networking.k8s.io'], resources: ['ingresses/status'], verbs: ['update'] },
    ],
  },
  ingressBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: { name: 'kosmos-cluster-http' },
    roleRef: { apiGroup: 'rbac.authorization.k8s.io', kind: 'ClusterRole', name: 'kosmos-cluster-http' },
    subjects: [{ kind: 'ServiceAccount', name: 'cluster-http', namespace: 'devops' }],
  },
  ingressDeployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: { name: 'cluster-http', namespace: 'devops', labels: labels },
    spec: {
      replicas: 1,
      strategy: { type: 'Recreate' },
      selector: { matchLabels: labels },
      template: {
        metadata: { labels: labels },
        spec: {
          serviceAccountName: 'cluster-http',
          containers: [{
            name: 'traefik',
            image: 'docker.io/library/traefik:v3.7.13',
            command: ['/usr/local/bin/traefik'],
            args: [
              '--entrypoints.http.address=:17480',
              '--entrypoints.http.transport.respondingtimeouts.readtimeout=0',
              '--entrypoints.http.http.sanitizepath=false',
              '--entrypoints.http.http.encodedcharacters.allowencodedslash=true',
              '--entrypoints.http.http.encodedcharacters.allowencodedpercent=true',
              '--entrypoints.http.http.encodedcharacters.allowencodedquestionmark=true',
              '--entrypoints.http.http.encodedcharacters.allowencodedhash=true',
              '--entrypoints.http.http.encodedcharacters.allowencodedsemicolon=true',
              '--entrypoints.http.forwardedheaders.trustedips=10.42.0.1/32',
              '--providers.kubernetesingress=true',
              '--providers.kubernetesingress.ingressclass=kosmos',
              '--providers.kubernetesingress.allowemptyservices=true',
              '--entrypoints.health.address=:8082',
              '--ping=true',
              '--ping.entrypoint=health',
              '--api=false',
              '--global.checknewversion=false',
              '--global.sendanonymoususage=false',
            ],
            ports: [
              { name: 'http', containerPort: 17480, hostPort: 27480, hostIP: '127.0.0.1' },
              { name: 'health', containerPort: 8082 },
            ],
            readinessProbe: { httpGet: { path: '/ping', port: 'health' } },
            livenessProbe: { httpGet: { path: '/ping', port: 'health' } },
            resources: {
              requests: { cpu: '20m', memory: '64Mi' },
              limits: { cpu: '250m', memory: '256Mi' },
            },
            securityContext: {
              runAsNonRoot: true,
              runAsUser: 65532,
              runAsGroup: 65532,
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              capabilities: { drop: ['ALL'] },
              seccompProfile: { type: 'RuntimeDefault' },
            },
          }],
        },
      },
    },
  },
  ingressService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: { name: 'cluster-http', namespace: 'devops' },
    spec: {
      type: 'ClusterIP',
      selector: labels,
      ports: [{ name: 'http', port: 17480, targetPort: 'http' }],
    },
  },
}
