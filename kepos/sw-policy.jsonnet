std.manifestTomlEx({
  network: { bootstrap: [
    '47.94.213.63:49737', '203.91.75.19:49738',
    '34.143.181.65:49738', '134.209.3.19:49739',
  ] },
  gateway: { host: '127.0.0.1', port: 17480 },
  peers: [{
    label: 'kosmos-wsl',
    public_key: 'e499c38286e33f481b64888c68e8a877872c17991d1465ae71b89272db80a304',
    connection: 'dial',
  }],
  services: [],
  bindings: [
    { peer: 'kosmos-wsl', service: 'mihomo', listen: { local_port: 17890 } },
    { peer: 'kosmos-wsl', service: 'dagger', listen: { local_port: 18080 } },
  ],
}, '  ')
