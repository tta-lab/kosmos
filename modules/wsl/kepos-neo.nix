{
  kepos-neo,
  lib,
  pkgs,
  ...
}: let
  package = kepos-neo.packages.x86_64-linux.kepos;
  publisherStateDir = "/home/neil/.local/state/kepos-neo/mux-publisher";
  # This is deliberately not a Home Manager-managed file. Kepos reloads its
  # policy from it every second. Render it atomically from
  # kepos/publisher-policy.jsonnet so ACL and service changes do not need a
  # rebuild or publisher restart.
  publisherPolicyFile = "/home/neil/.config/kepos/publisher.toml";
  bootstrap = [
    "47.94.213.63:49737"
    "203.91.75.19:49738"
    "34.143.181.65:49738"
    "134.209.3.19:49739"
  ];
  # Direct WSL-to-Mac traversal is unavailable on the current nested network.
  # Keep the complete subscriber wiring so it can be re-enabled later.
  enableMacSubscriber = false;
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
in {
  home-manager.users.neil = {
    home.packages = [package];

    systemd.user.services =
      {
        kepos-publisher = {
          Unit = {
            Description = "Kepos publisher";
            After = ["network-online.target"];
          };
          Install.WantedBy = ["default.target"];
          Service = {
            Type = "simple";
            ExecStart = lib.escapeShellArgs [
              (lib.getExe package)
              "publisher"
              "run"
              "--state"
              publisherStateDir
              "--config"
              publisherPolicyFile
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
      }
      // lib.optionalAttrs enableMacSubscriber {
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
