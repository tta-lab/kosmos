{
  config,
  lib,
  pkgs,
  ...
}: let
  k3sNodeAddress = "10.255.255.1";
  inherit (config.kosmos.wsl) proxy;
  k3sNoProxy = lib.concatStringsSep "," (
    proxy.noProxy
    ++ [
      proxy.podCidr
      proxy.serviceCidr
      ".svc"
      ".cluster.local"
      "forgejo.localhost"
      "woodpecker.localhost"
    ]
  );
in {
  networking.hosts."127.0.0.1" = [
    "forgejo.localhost"
    "woodpecker.localhost"
    "ente.localhost"
    "ente-storage.localhost"
    "bookorbit.localhost"
    "anki.localhost"
    "memos.localhost"
    "miniflux.localhost"
    "hindsight.localhost"
    "hindsightui.localhost"
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
      "--node-ip=${k3sNodeAddress}"
      "--write-kubeconfig-group=k3s"
      "--write-kubeconfig-mode=0640"
    ];
  };

  systemd.services = {
    k3s-node-address = {
      description = "Stable local node address for k3s";
      before = ["k3s.service"];
      path = [pkgs.iproute2];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ! ip link show dev k3s-node >/dev/null 2>&1; then
          ip link add k3s-node type dummy
        fi
        ip address replace ${k3sNodeAddress}/32 dev k3s-node
        ip link set k3s-node up
      '';
    };

    k3s = {
      wants = ["mihomo.service"];
      requires = ["k3s-node-address.service"];
      after = [
        "k3s-node-address.service"
        "mihomo.service"
      ];
      environment =
        proxy.environment
        // {
          NO_PROXY = k3sNoProxy;
          no_proxy = k3sNoProxy;
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
    "d /var/lib/kosmos-k3s/anki 0750 1000 1000 - -"
    "d /var/lib/kosmos-k3s/notes 0750 root root - -"
    "d /var/lib/kosmos-k3s/notes/memos 0750 10001 10001 - -"
    "d /var/lib/kosmos-k3s/feeds 0750 root root - -"
    "d /var/lib/kosmos-k3s/feeds/miniflux-db 0700 70 70 - -"
    "d /var/lib/kosmos-k3s/hindsight 0750 1000 1000 - -"
  ];
}
