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
    nuc-win = "c30b93a9864a8f33dffedf9816a6554de9acdf91a4a1e0cf85ca08747aeb7636";
    pixel7a = "d1c8e7bad4f0468a12d54c5b80d175677ff58c833f9e666f8a838b0d6b9256bc";
    aipaper = "0d88922a7b6de68ca5011398c846f60de49129bc0d9592e0437b580c41a7e625";
    guion-worker-1 = "ff9e2bee88a324ccf9ccdcc680a597e8798d008d57b54a4ae2873d26ddfea43e";
    guion-worker-2 = "682276873f44fd590054f68af34798651089b34d5dc70d9ecd151e8bd1a03a90";
    sw-server = "de087b86a5ced0d4f85e63463b8508e42ede89d2d4c9c9a64efd52697b1ce78b";
    baihe = "90165d47b541faad464be6c0718b15e16be5b170ec5616210c6b17ffdbf607c4";
    baihe-laptop = "21feb5140d9099a5589ffb6ddd5c29155346d9eb868991cd3fcce459fe24dbf3";
    # Replace with Guazi's 64-character Kepos subscriber public key.
    guazi = "fb9782436a1d150879f65ec7d4a2281376499011df9fc45830c5459a92540d32";
    # Replace this disposable valid key with Sven's actual Kepos subscriber key.
    sven-mac = "b1e5e5fd757e682f167d4aa68098368d8c7fe09372a14e90eb7154ddf63c4fd1";
  };
  fullTrustAllow = [
    subscribers.mac
    subscribers.nuc-win
  ];
  personalDevicesAllow =
    fullTrustAllow
    ++ [
      subscribers.pixel7a
      subscribers.aipaper
    ];
  forgeClientsAllow =
    fullTrustAllow
    ++ [
      subscribers.guion-worker-1
      subscribers.guion-worker-2
      subscribers.sw-server
    ];
  baiheAllow = [
    subscribers.baihe
    subscribers."baihe-laptop"
  ];
  guaziAllow = [subscribers.guazi];
  svenMacAllow = [subscribers."sven-mac"];
  publisherAllow = lib.unique (personalDevicesAllow ++ forgeClientsAllow ++ baiheAllow ++ guaziAllow ++ svenMacAllow);
in {
  home-manager.users.neil = {
    imports = [kepos-neo.homeManagerModules.default];

    services.kepos.publisher = {
      enable = true;
      inherit package bootstrap;
      stateDir = "/home/neil/.local/state/kepos-neo/mux-publisher";
      displayName = "kosmos-wsl";
      allow = publisherAllow;
      services = {
        forgejo = {
          name = "Forgejo";
          targetPort = 17480;
          allow = forgeClientsAllow ++ baiheAllow ++ svenMacAllow;
        };
        woodpecker = {
          name = "Woodpecker";
          targetPort = 17480;
          allow = forgeClientsAllow ++ baiheAllow ++ svenMacAllow;
        };
        navidrome = {
          name = "Navidrome";
          targetPort = 4533;
          allow = personalDevicesAllow ++ guaziAllow;
        };
        dsh = {
          name = "DeepSeek Harness";
          targetPort = 3080;
          # Full-trust devices + Pixel 7a phone.
          allow = fullTrustAllow ++ [subscribers.pixel7a];
        };
        dagger = {
          name = "Dagger";
          targetPort = 8080;
          allow = fullTrustAllow ++ svenMacAllow;
        };
        ente = {
          name = "Ente Photos";
          targetPort = 17480;
          allow = personalDevicesAllow ++ baiheAllow ++ guaziAllow ++ svenMacAllow;
        };
        ente-storage = {
          name = "Ente Storage";
          targetPort = 17480;
          allow = personalDevicesAllow ++ baiheAllow ++ guaziAllow ++ svenMacAllow;
        };
        bookorbit = {
          name = "BookOrbit";
          targetPort = 17480;
          allow = personalDevicesAllow ++ baiheAllow;
        };
        cloudreve = {
          name = "Cloudreve";
          targetPort = 17480;
          allow = personalDevicesAllow ++ svenMacAllow;
        };
        anki = {
          name = "Anki";
          targetPort = 17480;
          allow = personalDevicesAllow ++ guaziAllow;
        };
        memos = {
          name = "Memos";
          targetPort = 17480;
          allow = personalDevicesAllow ++ baiheAllow ++ guaziAllow;
        };
        miniflux = {
          name = "Miniflux";
          targetPort = 17480;
          allow = personalDevicesAllow;
        };
        hindsight = {
          name = "Hindsight";
          targetPort = 17480;
          allow = fullTrustAllow;
        };
        hindsightui = {
          name = "Hindsight UI";
          targetPort = 17480;
          allow = fullTrustAllow;
        };
        mihomo = {
          name = "Mihomo";
          targetPort = 7890;
          allow = personalDevicesAllow;
        };
        openclaw = {
          name = "OpenClaw";
          # Control UI; gateway auth via OPENCLAW_GATEWAY_TOKEN.
          targetPort = 18789;
          allow = fullTrustAllow ++ [subscribers.pixel7a];
        };
        mihomo-dashboard = {
          name = "Mihomo Dashboard";
          targetPort = 9090;
          allow = fullTrustAllow;
        };
        ssh = {
          name = "SSH";
          targetPort = 22;
          allow = personalDevicesAllow;
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
