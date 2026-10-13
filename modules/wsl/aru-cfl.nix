{
  config,
  lib,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.aruCfl;
  service = name: upstreamPort: port: hostname: let
    prefix = "/home/neil/.local/share/aru-cfl-${name}";
    state = "/home/neil/.local/state/aru-cfl-${name}";
    entry = "${prefix}/current/src/cfl/cli.mjs";
  in {
    Unit = {
      Description = "Aru access node for CFL ${name}";
      After = ["network-online.target"];
      ConditionPathExists = entry;
    };
    Install.WantedBy = ["default.target"];
    Service = {
      Type = "simple";
      WorkingDirectory = "${prefix}/current";
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgsUnstable.nodejs_24)
        entry
        "--data-dir"
        state
        "--cfl-origin"
        "http://127.0.0.1:${toString upstreamPort}"
        "--base-url"
        "https://${hostname}"
        "--listen-host"
        "127.0.0.1"
        "--port"
        (toString port)
      ];
      StateDirectory = "aru-cfl-${name}";
      StateDirectoryMode = "0700";
      UMask = "0077";
      # The CLI prints a single-use pairing secret at startup. Keep it local.
      StandardOutput = "truncate:${state}/pairing.log";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
in {
  options.kosmos.wsl.aruCfl.enable = lib.mkEnableOption "Aru access to the existing CFL dev and prod companions";

  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services = {
      aru-cfl-dev = service "dev" 3082 8787 "aru-dev.lamplit.run";
      aru-cfl-prod = service "prod" 3084 8788 "aru.lamplit.run";
    };
  };
}
