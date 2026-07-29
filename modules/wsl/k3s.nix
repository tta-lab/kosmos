{config, ...}: {
  networking.hosts."127.0.0.1" = [
    "forgejo.localhost"
    "woodpecker.localhost"
    "ente.localhost"
    "ente-storage.localhost"
    "bookorbit.localhost"
  ];

  networking.firewall.interfaces.cni0.allowedTCPPorts = [
    26443
  ];

  users.groups.k3s.members = ["neil"];

  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      "forgejo.localhost:17480":
        endpoint:
          - "http://forgejo.localhost:17480"
  '';

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable=servicelb"
      "--disable=traefik"
      "--https-listen-port=26443"
      "--write-kubeconfig-group=k3s"
      "--write-kubeconfig-mode=0640"
    ];
  };

  systemd.services = {
    k3s = {
      wants = ["mihomo.service"];
      after = ["mihomo.service"];
      environment = {
        HTTP_PROXY = config.kosmos.wsl.k3sProxyUrl;
        HTTPS_PROXY = config.kosmos.wsl.k3sProxyUrl;
        NO_PROXY = "localhost,127.0.0.1,::1,10.42.0.0/16,10.43.0.0/16,.svc,.cluster.local,forgejo.localhost,woodpecker.localhost";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/kosmos-k3s 0750 root root - -"
    "d /var/lib/kosmos-k3s/forgejo 0750 1000 1000 - -"
    "d /var/lib/kosmos-k3s/woodpecker 0750 1000 1000 - -"
    "d /var/lib/kosmos-k3s/dagger 0750 root root - -"
    "d /var/lib/kosmos-k3s/ente 0750 root root - -"
    "d /var/lib/kosmos-k3s/ente/postgres 0700 999 999 - -"
    "d /var/lib/kosmos-k3s/ente/garage 0750 root root - -"
    "d /var/lib/kosmos-k3s/ebooks 0750 root root - -"
    "d /var/lib/kosmos-k3s/ebooks/bookorbit 0750 1000 1000 - -"
    "d /var/lib/kosmos-k3s/ebooks/bookorbit/data 0750 1000 1000 - -"
    "d /var/lib/kosmos-k3s/ebooks/bookorbit/books 0750 1000 1000 - -"
    "d /var/lib/kosmos-k3s/ebooks/bookorbit-db 0700 999 999 - -"
  ];
}
