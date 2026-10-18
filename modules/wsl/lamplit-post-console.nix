{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.postConsole;
  pnpm = pkgsUnstable.callPackage ../../packages/pnpm {};
  prepare = pkgs.writeShellApplication {
    name = "prepare-post-console";
    text = builtins.readFile ../../scripts/prepare-post-console;
  };
in {
  options.kosmos.wsl.postConsole = {
    enable = lib.mkEnableOption "native managed Post application";
    appRoot = lib.mkOption {
      type = lib.types.str;
      default = "/home/neil/.local/share/lamplit-post/app";
      description = "Persistent writable application root, initialized once by the operator.";
    };
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services.lamplit-post-console = {
      Unit = {
        Description = "Lamplit Post native managed Console";
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "exec";
        # ExecCondition provides a diagnostic and skips startup without a restart loop.
        ExecCondition = lib.escapeShellArgs ["${prepare}/bin/prepare-post-console" cfg.appRoot];
        # Ignore absent cwd so ExecCondition can diagnose and skip an uninitialized app.
        WorkingDirectory = "-${cfg.appRoot}";
        ExecStartPre = lib.escapeShellArgs [(lib.getExe pnpm) "run" "config-check"];
        ExecStart = lib.escapeShellArgs [(lib.getExe pnpm) "run" "start"];
        Environment = ["PATH=${lib.makeBinPath [pnpm pkgsUnstable.nodejs_24 pkgs.coreutils pkgs.bash]}"];
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        KillMode = "control-group";
        KillSignal = "SIGTERM";
        TimeoutStartSec = 30;
        TimeoutStopSec = 30;
        NoNewPrivileges = true;
        StandardInput = "null";
      };
    };
  };
}
