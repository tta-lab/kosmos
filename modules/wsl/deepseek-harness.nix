{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.deepseekHarness;
  # The packed tree gives bare plugins a resolvable npm dependency base.
  runtime = "/home/neil/.local/share/dsh-runtime";
  entrypoint = "${runtime}/node_modules/@deepseek-ai/dsh/lib/bin.js";
  stateDirectory = "/home/neil/.local/state/dsh";
  mcpPatch = ./deepseek-harness-mcp.cordis.yml;
  # Remote DSH credential writes stay loopback-only by design. Reuse the
  # existing agenix-managed DeepSeek key instead of weakening that boundary.
  deepseekKey = config.age.secrets."openclaw-deepseek-key".path;
  dshCommand = [
    (lib.getExe pkgsUnstable.nodejs_24)
    "--expose-internals"
    entrypoint
    "web"
    "--patch"
    (toString mcpPatch)
    "--host"
    "127.0.0.1"
    "--port"
    "3080"
    "--trusted-host"
    "dsh.localhost:17480"
  ];
  dshStart = pkgs.writeShellScript "dsh-start" ''
    set -eu
    key="$( ${pkgs.coreutils}/bin/cat -- ${lib.escapeShellArg deepseekKey} )"
    if [ -z "$key" ]; then
      echo "dsh: DeepSeek credential is empty" >&2
      exit 1
    fi
    export DEEPSEEK_API_KEY="$key"
    exec ${lib.escapeShellArgs dshCommand}
  '';
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
        WorkingDirectory = "/home/neil";
        ExecStartPre = lib.escapeShellArgs [
          "${pkgs.coreutils}/bin/install"
          "-d"
          "-m"
          "0700"
          stateDirectory
        ];
        ExecStart = dshStart;
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
