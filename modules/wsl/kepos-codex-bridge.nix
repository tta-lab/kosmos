{
  config,
  lib,
  ...
}: let
  bridgeExecutable = "/home/neil/.local/bin/kepos-codex-bridge";
  authFile = "/home/neil/.codex/auth.json";
  bridgePort = 8787;
  proxyEnvironment = lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
in {
  home-manager.users.neil.systemd.user.services.kepos-codex-bridge = {
    Unit = {
      Description = "Kepos Codex Responses bridge";
      After = ["network-online.target"];
    };
    Install.WantedBy = ["default.target"];
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/neil";
      ExecStart = lib.escapeShellArgs [
        bridgeExecutable
        "serve"
        "--auth-file"
        authFile
        "--port"
        (toString bridgePort)
      ];
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      Environment = proxyEnvironment;
    };
  };
}
