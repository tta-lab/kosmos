{kepos-neo, ...}: let
  subscribers = {
    mac = "c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2";
    pixel7a = "d1c8e7bad4f0468a12d54c5b80d175677ff58c833f9e666f8a838b0d6b9256bc";
    guion-worker-1 = "ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e";
    guion-worker-2 = "682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90";
    sw-server = "de087b86a5ced0d4f85e63463b8508e42ede89d2d4c9c9a64efd52697b1ce78b";
    lemon = "f8bcb7c20d24d3a295fdec2a5a250adef59b3d7e70b21592a01de99b63cae6de";
  };
  forgeServicesAllow = [
    subscribers.mac
    subscribers.guion-worker-1
    subscribers.guion-worker-2
    subscribers.sw-server
  ];
in {
  home-manager.users.neil = {
    imports = [kepos-neo.homeManagerModules.default];

    services.kepos.publisher = {
      enable = true;
      package = kepos-neo.packages.x86_64-linux.kepos;
      stateDir = "/home/neil/.local/state/kepos-neo/mux-publisher";
      displayName = "kosmos-wsl";
      bootstrap = [
        "47.94.213.63:49737"
        "203.91.75.19:49738"
        "34.143.181.65:49738"
        "134.209.3.19:49739"
      ];
      allow = [
        subscribers.mac
        subscribers.pixel7a
        subscribers.guion-worker-1
        subscribers.guion-worker-2
        subscribers.lemon
        subscribers.sw-server
      ];
      services = {
        forgejo = {
          name = "Forgejo";
          targetPort = 17480;
          allow = forgeServicesAllow;
        };
        woodpecker = {
          name = "Woodpecker";
          targetPort = 17480;
          allow = forgeServicesAllow;
        };
        navidrome = {
          name = "Navidrome";
          targetPort = 4533;
        };
        dagger = {
          name = "Dagger";
          targetPort = 8080;
          allow = [subscribers.mac];
        };
        ente = {
          name = "Ente Photos";
          targetPort = 17480;
        };
        ente-storage = {
          name = "Ente Storage";
          targetPort = 17480;
        };
        bookorbit = {
          name = "BookOrbit";
          targetPort = 17480;
        };
        anki = {
          name = "Anki";
          targetPort = 17480;
        };
        memos = {
          name = "Memos";
          targetPort = 17480;
        };
        mihomo = {
          name = "Mihomo";
          targetPort = 7890;
        };
        mihomo-dashboard = {
          name = "Mihomo Dashboard";
          targetPort = 9090;
          allow = [subscribers.mac];
        };
        ssh = {
          name = "SSH";
          targetPort = 22;
        };
      };
    };
  };
}
