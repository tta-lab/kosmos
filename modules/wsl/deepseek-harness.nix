{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.deepseekHarness;
  repository = "/home/neil/code/projects/tta-lab/deepseek-harness";
  stateDirectory = "/home/neil/.local/state/dsh";
  proxyUrl = config.kosmos.wsl.k3sProxyUrl;
  noProxy = "localhost,127.0.0.1,::1";
  proxyEnvironment = [
    "HTTP_PROXY=${proxyUrl}"
    "HTTPS_PROXY=${proxyUrl}"
    "ALL_PROXY=${proxyUrl}"
    "NO_PROXY=${noProxy}"
    "http_proxy=${proxyUrl}"
    "https_proxy=${proxyUrl}"
    "all_proxy=${proxyUrl}"
    "no_proxy=${noProxy}"
  ];
in {
  options.kosmos.wsl.deepseekHarness.enable = lib.mkEnableOption "the DeepSeek Harness web UI";

  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services.dsh = {
      Unit.Description = "DeepSeek Harness web UI";
      Install.WantedBy = ["default.target"];
      Service = {
        WorkingDirectory = repository;
        ExecStartPre = lib.escapeShellArgs [
          "${pkgs.coreutils}/bin/install"
          "-d"
          "-m"
          "0700"
          stateDirectory
        ];
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgsUnstable.pnpm)
          "dsh"
          "web"
          "--host"
          "127.0.0.1"
          "--port"
          "3080"
          "--trusted-host"
          "dsh.localhost:17480"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        Environment =
          [
            "DSH_HOME=${stateDirectory}"
            "NODE_USE_ENV_PROXY=1"
            "PATH=/home/neil/.local/bin:/home/neil/go/bin:/home/neil/.local/share/npm-global/bin:/run/current-system/sw/bin"
          ]
          ++ proxyEnvironment;
      };
    };
  };
}
