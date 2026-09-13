// Kepos peer policy source. Render atomically with
// `just kepos-policy-render`; Kepos then hot-reloads the TOML output.
local bootstrap = [
  '47.94.213.63:49737',
  '203.91.75.19:49738',
  '34.143.181.65:49738',
  '134.209.3.19:49739',
];

local peers = {
  mac: {
    label: 'mac',
    public_key: 'c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2',
  },
  'nuc-win': {
    label: 'nuc-win',
    public_key: 'c30b93a9864a8f33dffedf9816a6554de9acdf91a4a1e0cf85ca08747aeb7636',
  },
  pixel7a: {
    label: 'pixel7a',
    public_key: 'd1c8e7bad4f0468a12d54c5b80d175677ff58c833f9e666f8a838b0d6b9256bc',
  },
  xiaomi: {
    label: 'xiaomi',
    public_key: 'bf916f4553e368b0a28ea93427de641a605e167bc57d0fd8adb2be75505191c2',
  },
  aipaper: {
    label: 'aipaper',
    public_key: '0d88922a7b6de68ca5011398c846f60de49129bc0d9592e0437b580c41a7e625',
  },
  'guion-worker-1': {
    label: 'guion-worker-1',
    public_key: 'ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e',
  },
  'guion-worker-2': {
    label: 'guion-worker-2',
    public_key: '682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90',
  },
  'sw-server': {
    label: 'sw-server',
    public_key: 'de087b86a5ced0d4f85e63463b8508e42ede89d2d4c9c9a64efd52697b1ce78b',
  },
  baihe: {
    label: 'baihe',
    public_key: '90165d47b541faad464be6c0718b15e16be5b170ec5616210c6b17ffdbf607c4',
  },
  'baihe-laptop': {
    label: 'baihe-laptop',
    public_key: '21feb5140d9099a5589ffb6ddd5c29155346d9eb868991cd3fcce459fe24dbf3',
  },
  guazi: {
    label: 'guazi',
    public_key: 'fb9782436a1d150879f65ec7d4a2281376499011df9fc45830c5459a92540d32',
  },
  'sven-mac': {
    label: 'sven-mac',
    public_key: 'ed2300f4d4482866af5fef79baff0307b3e29ef6ffd250aa2559f116d282664a',
  },
  'codex-bridge': {
    label: 'codex-bridge',
    public_key: '7cee61458c3a5dcc59027feebc855d540c97e4d09bcca6c6cfcf13ce0457bc62',
  },
  lili: {
    label: 'lili',
    public_key: '7e467b8465c11390c6150e093bbc3ee8cec8d8049c9e80efa4a500c394af643e',
  },
};

local peerDevices = [peer + {connection: 'accept'} for peer in std.objectValues(peers)];
local fullTrustAllow = [
  peers.mac.public_key,
  peers['nuc-win'].public_key,
];
local personalDevicesAllow = fullTrustAllow + [
  peers.pixel7a.public_key,
  peers.aipaper.public_key,
];
local forgeClientsAllow = fullTrustAllow + [
  peers['guion-worker-1'].public_key,
  peers['guion-worker-2'].public_key,
  peers['sw-server'].public_key,
];
local guionWorkersAllow = [
  peers['guion-worker-1'].public_key,
  peers['guion-worker-2'].public_key,
];
local baiheAllow = [
  peers.baihe.public_key,
  peers['baihe-laptop'].public_key,
];
local guaziAllow = [peers.guazi.public_key];
local svenMacAllow = [peers['sven-mac'].public_key];
local codexBridgeAllow = [peers['codex-bridge'].public_key];
local liliAllow = [peers.lili.public_key];
local xiaomiAllow = [peers.xiaomi.public_key];
local impriAllow = [
  peers.mac.public_key,
  peers.pixel7a.public_key,
];
local service(id, name, targetPort, allow, kind = null) = {
  id: id,
  name: name,
  source: {local_port: targetPort},
  allow: allow,
} + (if kind == null then {} else { kind: kind });

std.manifestTomlEx({
  network: {bootstrap: bootstrap},
  gateway: {host: '127.0.0.1', port: 17481},
  peers: peerDevices,
  bindings: [
    {
      peer: 'mac',
      service: 'ssh',
      listen: {local_port: 2222},
    },
  ],
  services: [
    service('anki', 'Anki', 17480, personalDevicesAllow + guaziAllow),
    service('bookorbit', 'BookOrbit', 17480, personalDevicesAllow + baiheAllow),
    service('cloudreve', 'Cloudreve', 17480, personalDevicesAllow + baiheAllow + svenMacAllow + liliAllow),
    service('codex-bridge', 'Codex Bridge', 17480, fullTrustAllow + guionWorkersAllow + baiheAllow + codexBridgeAllow + liliAllow),
    service('dagger', 'Dagger', 8080, fullTrustAllow + svenMacAllow),
    service('dsh', 'DeepSeek Harness', 3080, fullTrustAllow + [peers.pixel7a.public_key] + xiaomiAllow),
    service('ente', 'Ente Photos', 17480, personalDevicesAllow + xiaomiAllow + baiheAllow + guaziAllow + svenMacAllow),
    service('ente-storage', 'Ente Storage', 17480, personalDevicesAllow + xiaomiAllow + baiheAllow + guaziAllow + svenMacAllow),
    service('erpnext', 'ERPNext', 17480, fullTrustAllow + svenMacAllow),
    service('forgejo', 'Forgejo', 17480, forgeClientsAllow + baiheAllow + svenMacAllow + liliAllow) + {
      max_publisher_to_subscriber_bps: 2000000,
    },
    service('grafana', 'Grafana', 17480, fullTrustAllow),
    service('hindsight', 'Hindsight', 17480, fullTrustAllow),
    service('hindsightui', 'Hindsight UI', 17480, fullTrustAllow),
    service('impri', 'Impri', 17480, impriAllow),
    service('memos', 'Memos', 17480, personalDevicesAllow + xiaomiAllow + baiheAllow + guaziAllow),
    service('mihomo', 'Mihomo', 7890, personalDevicesAllow + xiaomiAllow + liliAllow),
    service('mihomo-dashboard', 'Mihomo Dashboard', 9090, fullTrustAllow),
    service('miniflux', 'Miniflux', 17480, personalDevicesAllow),
    service('navidrome', 'Navidrome', 4533, personalDevicesAllow + xiaomiAllow + guaziAllow),
    service('ssh', 'SSH', 22, personalDevicesAllow),
    service('woodpecker', 'Woodpecker', 17480, forgeClientsAllow + baiheAllow + svenMacAllow),
  ],
}, '  ')
