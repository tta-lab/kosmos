{
  kepos-neo,
  pkgs,
  ...
}: let
  kepos = pkgs.callPackage ../../packages/kepos-neo {
    src = kepos-neo;
  };
  stateDir = "/home/neil/.local/state/kepos-neo/mux-publisher";
in {
  environment.systemPackages = [kepos];

  home-manager.users.neil = {
    xdg.configFile."kepos/config.toml".text = ''
      [network]
      bootstrap = [
        "47.94.213.63:49737",
        "203.91.75.19:49738",
        "34.143.181.65:49738",
        "134.209.3.19:49739",
      ]
    '';

    systemd.user.services.kepos-publisher = {
      Unit = {
        Description = "Kepos multiplex service publisher";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
        ConditionPathExists = "${stateDir}/publisher.manifest.json";
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = "${kepos}/bin/kepos publisher run --state ${stateDir} --config /home/neil/.config/kepos/config.toml";
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = "/home/neil";
        Environment = [
          "HOME=/home/neil"
          "NO_PROXY=localhost,127.0.0.1,::1"
        ];
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
