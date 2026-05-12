{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.frpcSsh;
  mkStartScript = {
    name,
    userTokenVar,
    proxyIdsVar,
  }: let
    userTokenCheck = "$" + "{" + userTokenVar + ":?missing " + userTokenVar + "}";
    proxyIdsCheck = "$" + "{" + proxyIdsVar + ":?missing " + proxyIdsVar + "}";
    userTokenValue = "$" + "{" + userTokenVar + "}";
    proxyIdsValue = "$" + "{" + proxyIdsVar + "}";
  in
    pkgs.writeShellScript "openfrp-frpc-${name}-start" ''
      set -eu
      : "${userTokenCheck}"
      : "${proxyIdsCheck}"
      exec ${cfg.binaryPath} -u "${userTokenValue}" -p "${proxyIdsValue}" -n
    '';
  mkService = {
    description,
    name,
    proxyIdsVar,
    stateDirectory,
    userTokenVar,
  }: {
    inherit description;
    wants = ["network-online.target"];
    after = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    unitConfig.ConditionPathIsExecutable = cfg.binaryPath;
    serviceConfig = {
      Type = "simple";
      User = "openfrp";
      Group = "openfrp";
      StateDirectory = stateDirectory;
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/${stateDirectory}";
      EnvironmentFile = config.age.secrets.frpc-env.path;
      ExecStart = mkStartScript {
        inherit name proxyIdsVar userTokenVar;
      };
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

    systemd.services = {
      openfrp-frpc-slow = mkService {
        description = "OpenFrp frpc slow SSH tunnel";
        name = "slow";
        proxyIdsVar = "OPENFRP_PROXY_IDS_SLOW";
        stateDirectory = "openfrp-frpc-slow";
        userTokenVar = "OPENFRP_USER_TOKEN_SLOW";
      };

      openfrp-frpc-fast = mkService {
        description = "OpenFrp frpc fast SSH tunnel";
        name = "fast";
        proxyIdsVar = "OPENFRP_PROXY_IDS_FAST";
        stateDirectory = "openfrp-frpc-fast";
        userTokenVar = "OPENFRP_USER_TOKEN_FAST";
      };
    };
  };
}
