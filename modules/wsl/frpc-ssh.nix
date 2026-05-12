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
      default = "/opt/openfrp/openfrp-frpc";
      description = "OpenFrp frpc binary path installed outside this repo.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.frpc-env = {
      file = ../../secrets/frpc-env.age;
      owner = "openfrp";
      group = "openfrp";
      mode = "0400";
    };

    users.groups.openfrp = {};
    users.users.openfrp = {
      isSystemUser = true;
      group = "openfrp";
    };

    systemd.services.openfrp-frpc = {
      description = "OpenFrp frpc SSH tunnel";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      unitConfig.ConditionPathIsExecutable = cfg.binaryPath;
      serviceConfig = {
        Type = "simple";
        User = "openfrp";
        Group = "openfrp";
        StateDirectory = "openfrp-frpc";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/openfrp-frpc";
        EnvironmentFile = config.age.secrets.frpc-env.path;
        ExecStart = startOpenfrpFrpc;
        Restart = "on-failure";
        RestartSec = 15;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
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
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service"];
      };
    };
  };
}
