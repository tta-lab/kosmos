{
  kepos-neo,
  lib,
  pkgs,
  ...
}: let
  package = kepos-neo.packages.x86_64-linux.kepos;
  # Direct WSL-to-Mac traversal is unavailable on the current nested network.
  # Keep the complete subscriber wiring so it can be re-enabled later.
  enableMacSubscriber = false;
  bootstrap = [
    "47.94.213.63:49737"
    "203.91.75.19:49738"
    "34.143.181.65:49738"
    "134.209.3.19:49739"
  ];
  subscriberStateDir = "/home/neil/.local/state/kepos-neo/subscriber";
  macPublisherKey = "2cb7ff31ed689b79259b97043c2b3e8fbd3ae8e905d6c17b1738e8bfbd2716da";
  subscriberConfigFile = (pkgs.formats.toml {}).generate "kepos-subscriber-config.toml" {
    network = {inherit bootstrap;};
    subscriber = {
      enabled = true;
      gateway_port = 17481;
      route = "auto";
      services = [
        {
          id = "ssh";
          local_port = 2222;
        }
      ];
    };
  };
  subscribers = {
    mac = "c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2";
    pixel7a = "d1c8e7bad4f0468a12d54c5b80d175677ff58c833f9e666f8a838b0d6b9256bc";
    aipaper = "0d88922a7b6de68ca5011398c846f60de49129bc0d9592e0437b580c41a7e625";
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
      inherit package bootstrap;
      stateDir = "/home/neil/.local/state/kepos-neo/mux-publisher";
      displayName = "kosmos-wsl";
      allow = [
        subscribers.mac
        subscribers.pixel7a
        subscribers.aipaper
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
        hindsight = {
          name = "Hindsight";
          targetPort = 17480;
          allow = [subscribers.mac];
        };
        hindsightui = {
          name = "Hindsight UI";
          targetPort = 17480;
          allow = [subscribers.mac];
        };
        mihomo = {
          name = "Mihomo";
          targetPort = 7890;
        };
        openclaw = {
          name = "OpenClaw";
          # Control UI; gateway auth via OPENCLAW_GATEWAY_TOKEN.
          targetPort = 18789;
          allow = [subscribers.mac];
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

    systemd.user.services = lib.optionalAttrs enableMacSubscriber {
      kepos-subscriber = {
        Unit = {
          Description = "Kepos Neo subscriber for the Mac publisher";
          After = ["network-online.target"];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          Type = "simple";
          ExecStartPre = [
            (lib.escapeShellArgs [
              (lib.getExe package)
              "setup"
              "subscriber"
              "--state"
              subscriberStateDir
            ])
            (lib.escapeShellArgs [
              (lib.getExe package)
              "subscriber"
              "set-publisher"
              "--state"
              subscriberStateDir
              "--label"
              "neil-mac"
              "--publisher-key"
              macPublisherKey
            ])
          ];
          ExecStart = lib.escapeShellArgs [
            (lib.getExe package)
            "subscriber"
            "run"
            "--state"
            subscriberStateDir
            "--config"
            (toString subscriberConfigFile)
            "--observations"
            "ndjson"
          ];
          Restart = "always";
          RestartSec = 5;
          KillMode = "mixed";
          TimeoutStopSec = 15;
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };
    };
  };
}
