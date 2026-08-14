local topology = import '../../modules/wsl/proxy-topology.json';
local endpoint(host) = host + ':' + std.toString(topology.listener.port);

{
  podUrl: 'http://' + endpoint(topology.podProxyHost),
  clusterNoProxy(extra=[]):
    std.join(',', topology.baseNoProxy + [
      topology.podCidr,
      topology.serviceCidr,
      '.svc',
      '.cluster.local',
    ] + extra),
}
