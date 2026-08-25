// Kepos publisher policy source. Render atomically with
// `just kepos-policy-render`; Kepos then hot-reloads the TOML output.
local bootstrap = [
  '47.94.213.63:49737',
  '203.91.75.19:49738',
  '34.143.181.65:49738',
  '134.209.3.19:49739',
];

local subscribers = {
  mac: 'c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2',
  'nuc-win': 'c30b93a9864a8f33dffedf9816a6554de9acdf91a4a1e0cf85ca08747aeb7636',
  pixel7a: 'd1c8e7bad4f0468a12d54c5b80d175677ff58c833f9e666f8a838b0d6b9256bc',
  aipaper: '0d88922a7b6de68ca5011398c846f60de49129bc0d9592e0437b580c41a7e625',
  'guion-worker-1': 'ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e',
  'guion-worker-2': '682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90',
  'sw-server': 'de087b86a5ced0d4f85e63463b8508e42ede89d2d4c9c9a64efd52697b1ce78b',
  baihe: '90165d47b541faad464be6c0718b15e16be5b170ec5616210c6b17ffdbf607c4',
  'baihe-laptop': '21feb5140d9099a5589ffb6ddd5c29155346d9eb868991cd3fcce459fe24dbf3',
  guazi: 'fb9782436a1d150879f65ec7d4a2281376499011df9fc45830c5459a92540d32',
  'sven-mac': 'b1e5e5fd757e682f167d4aa68098368d8c7fe09372a14e90eb7154ddf63c4fd1',
};

local fullTrustAllow = [
  subscribers.mac,
  subscribers['nuc-win'],
];
local personalDevicesAllow = fullTrustAllow + [
  subscribers.pixel7a,
  subscribers.aipaper,
];
local forgeClientsAllow = fullTrustAllow + [
  subscribers['guion-worker-1'],
  subscribers['guion-worker-2'],
  subscribers['sw-server'],
];
local baiheAllow = [
  subscribers.baihe,
  subscribers['baihe-laptop'],
];
local guaziAllow = [subscribers.guazi];
local svenMacAllow = [subscribers['sven-mac']];
local unique(values) = std.foldl(
  function(acc, value) if std.member(acc, value) then acc else acc + [value],
  values,
  []
);
local publisherAllow = unique(
  personalDevicesAllow + forgeClientsAllow + baiheAllow + guaziAllow + svenMacAllow
);
local service(id, name, targetPort, allow) = {
  id: id,
  name: name,
  target_port: targetPort,
  allow: allow,
};

std.manifestTomlEx({
  network: {bootstrap: bootstrap},
  publisher: {
    display_name: 'kosmos-wsl',
    allow: publisherAllow,
    services: [
      service('anki', 'Anki', 17480, personalDevicesAllow + guaziAllow),
      service('bookorbit', 'BookOrbit', 17480, personalDevicesAllow + baiheAllow),
      service('cloudreve', 'Cloudreve', 17480, personalDevicesAllow + baiheAllow + svenMacAllow),
      service('codex-bridge', 'Codex Bridge', 8787, [subscribers.mac] + baiheAllow),
      service('dagger', 'Dagger', 8080, fullTrustAllow + svenMacAllow),
      service('dsh', 'DeepSeek Harness', 3080, fullTrustAllow + [subscribers.pixel7a]),
      service('ente', 'Ente Photos', 17480, personalDevicesAllow + baiheAllow + guaziAllow + svenMacAllow),
      service('ente-storage', 'Ente Storage', 17480, personalDevicesAllow + baiheAllow + guaziAllow + svenMacAllow),
      service('erpnext', 'ERPNext', 17480, fullTrustAllow + svenMacAllow),
      service('forgejo', 'Forgejo', 17480, forgeClientsAllow + baiheAllow + svenMacAllow),
      service('hindsight', 'Hindsight', 17480, fullTrustAllow),
      service('hindsightui', 'Hindsight UI', 17480, fullTrustAllow),
      service('memos', 'Memos', 17480, personalDevicesAllow + baiheAllow + guaziAllow),
      service('mihomo', 'Mihomo', 7890, personalDevicesAllow),
      service('mihomo-dashboard', 'Mihomo Dashboard', 9090, fullTrustAllow),
      service('miniflux', 'Miniflux', 17480, personalDevicesAllow),
      service('navidrome', 'Navidrome', 4533, personalDevicesAllow + guaziAllow),
      service('openclaw', 'OpenClaw', 18789, fullTrustAllow + [subscribers.pixel7a]),
      service('ssh', 'SSH', 22, personalDevicesAllow),
      service('woodpecker', 'Woodpecker', 17480, forgeClientsAllow + baiheAllow + svenMacAllow),
    ],
  },
}, '  ')
