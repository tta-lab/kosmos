{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.frpcSsh;
  startOpenfrpFrpc = pkgs.writeShellScript "openfrp-frpc-start" ''
    set -eu
    : "''${OPENFRP_USER_TOKEN:?missing OPENFRP_USER_TOKEN}"
    : "''${OPENFRP_PROXY_IDS:?missing OPENFRP_PROXY_IDS}"
    exec ${cfg.binaryPath} -u "$OPENFRP_USER_TOKEN" -p "$OPENFRP_PROXY_IDS" -n
  '';
in {
  options.kosmos.wsl.frpcSsh = {
    enable = lib.mkEnableOption "frpc SSH tunnel for kosmos-wsl";

    binaryPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/neil/.local/bin/openfrp-frpc";
      description = "OpenFrp frpc binary path installed outside this repo.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.frpc-env = {
      file = ../../secrets/frpc-env.age;
      owner = "neil";
      group = "users";
      mode = "0400";
    };

    home-manager.users.neil.systemd.user.services.openfrp-frpc = {
      Unit = {
        Description = "OpenFrp frpc SSH tunnel";
        After = ["network-online.target"];
        ConditionPathIsExecutable = cfg.binaryPath;
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "simple";
        EnvironmentFile = config.age.secrets.frpc-env.path;
        ExecStart = startOpenfrpFrpc;
        Restart = "on-failure";
        RestartSec = 15;
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service"];
      };
    };
  };
}
