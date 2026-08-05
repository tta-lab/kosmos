{
  kepos-neo,
  lib,
  pkgs,
  ...
}: let
  package = kepos-neo.packages.x86_64-linux.kepos;
  toml = pkgs.formats.toml {};
  bootstrap = [
    "47.94.213.63:49737"
    "203.91.75.19:49738"
    "34.143.181.65:49738"
    "134.209.3.19:49739"
  ];
  publisherStateDir = "/home/neil/.local/state/kepos-neo/mux-publisher";
  subscriberStateDir = "/home/neil/.local/state/kepos-neo/subscriber";
  macPublisherKey = "2cb7ff31ed689b79259b97043c2b3e8fbd3ae8e905d6c17b1738e8bfbd2716da";
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
  publisherAllow = [
    subscribers.mac
    subscribers.pixel7a
    subscribers.guion-worker-1
    subscribers.guion-worker-2
    subscribers.lemon
    subscribers.sw-server
  ];
  deviceConfigFile = toml.generate "kepos-device-config.toml" {
    network = {inherit bootstrap;};
    publisher = {
      enabled = true;
      display_name = "kosmos-wsl";
      allow = publisherAllow;
      services = [
        {
          id = "forgejo";
          name = "Forgejo";
          target_port = 17480;
          allow = forgeServicesAllow;
        }
        {
          id = "woodpecker";
          name = "Woodpecker";
          target_port = 17480;
          allow = forgeServicesAllow;
        }
        {
          id = "navidrome";
          name = "Navidrome";
          target_port = 4533;
        }
        {
          id = "dagger";
          name = "Dagger";
          target_port = 8080;
          allow = [subscribers.mac];
        }
        {
          id = "ente";
          name = "Ente Photos";
          target_port = 17480;
        }
        {
          id = "ente-storage";
          name = "Ente Storage";
          target_port = 17480;
        }
        {
          id = "bookorbit";
          name = "BookOrbit";
          target_port = 17480;
        }
        {
          id = "anki";
          name = "Anki";
          target_port = 17480;
        }
        {
          id = "memos";
          name = "Memos";
          target_port = 17480;
        }
        {
          id = "mihomo";
          name = "Mihomo";
          target_port = 7890;
        }
        {
          id = "mihomo-dashboard";
          name = "Mihomo Dashboard";
          target_port = 9090;
          allow = [subscribers.mac];
        }
        {
          id = "ssh";
          name = "SSH";
          target_port = 22;
        }
      ];
    };
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
  initializePublisher = pkgs.writeShellApplication {
    name = "kepos-initialize-publisher";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      state_dir=${lib.escapeShellArg publisherStateDir}
      if [[ -f "$state_dir/publisher.manifest.json" && -f "$state_dir/publisher.json" ]]; then
        exit 0
      fi
      if [[ -e "$state_dir" ]]; then
        echo "Kepos publisher state is partial or invalid: $state_dir" >&2
        exit 1
      fi

      umask 077
      mkdir -p "$(dirname "$state_dir")"
      exec ${lib.getExe package} setup publisher \
        --state "$state_dir" \
        --config ${lib.escapeShellArg (toString deviceConfigFile)}
    '';
  };
in {
  home-manager.users.neil = {
    home.packages = [package];
    xdg.configFile."kepos/config.toml".source = deviceConfigFile;

    systemd.user.services.kepos-device = {
      Unit = {
        Description = "Kepos dual-role device";
        After = ["network-online.target"];
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "simple";
        ExecStartPre = [
          (lib.getExe initializePublisher)
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
          "device"
          "run"
          "--publisher-state"
          publisherStateDir
          "--subscriber-state"
          subscriberStateDir
          "--config"
          (toString deviceConfigFile)
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
}
