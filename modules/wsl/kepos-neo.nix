{kepos-neo, ...}: let
  subscribers = {
    mac = "c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2";
    subscriber-80745c = "80745ccfb5cb1ec8f10faf19225c0add320b1dc2e3a65914f3789935422fee96";
    subscriber-e7cd23 = "e7cd23d4729148b6a6682c65787be743d63c48f96a3a2cb76ff07a72547be77e";
    guion-worker-1 = "ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e";
    guion-worker-2 = "682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90";
    lemon = "f8bcb7c20d24d3a295fdec2a5a250adef59b3d7e70b21592a01de99b63cae6de";
  };
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
        subscribers.subscriber-80745c
        subscribers.subscriber-e7cd23
        subscribers.guion-worker-1
        subscribers.guion-worker-2
        subscribers.lemon
      ];
      services = {
        forgejo = {
          name = "Forgejo";
          targetPort = 17480;
        };
        woodpecker = {
          name = "Woodpecker";
          targetPort = 17480;
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
