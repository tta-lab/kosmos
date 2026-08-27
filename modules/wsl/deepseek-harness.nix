{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.deepseekHarness;
  # Standalone dependency tree at ~/.local/share/dsh-runtime, installed from
  # the npm registry with bun, outside the Nix closure; only the pinned
  # entrypoint below is consumed. Install/upgrade/swap/rollback and plugin
  # troubleshooting: docs/dsh-deployment.md.
  runtime = "/home/neil/.local/share/dsh-runtime";
  runtimeBin = "${runtime}/node_modules/.bin";
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
  # The launcher handles the secret; systemd retains the non-secret DSH command.
  dshStart = pkgs.writeShellScript "dsh-start" ''
    set -eu
    key="$( ${pkgs.coreutils}/bin/cat -- ${lib.escapeShellArg deepseekKey} )"
    if [ -z "$key" ]; then
      echo "dsh: DeepSeek credential is empty" >&2
      exit 1
    fi
    export DEEPSEEK_API_KEY="$key"
    exec "$@"
  '';
  proxyEnvironment = lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
in {
  options.kosmos.wsl.deepseekHarness.enable = lib.mkEnableOption "the DeepSeek Harness web UI";

  config = lib.mkIf cfg.enable {
    home-manager.users.neil.home.sessionPath = [runtimeBin];

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
        ExecStart = lib.escapeShellArgs ([dshStart] ++ dshCommand);
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
