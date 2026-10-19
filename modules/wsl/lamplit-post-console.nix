{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.postConsole;
  node = lib.getExe pkgsUnstable.nodejs_24;
  prepare = pkgs.writeShellApplication {
    name = "prepare-post-console";
    runtimeInputs = [pkgsUnstable.nodejs_24];
    text = builtins.readFile ../../scripts/prepare-post-console;
  };
in {
  options.kosmos.wsl.postConsole = {
    enable = lib.mkEnableOption "standalone Post settings service";
    releaseRoot = lib.mkOption {
      type = lib.types.str;
      default = "/home/neil/.local/share/lamplit-post/current";
      description = "Operator-selected immutable complete standalone release.";
    };
    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/neil/.local/state/lamplit-post/standalone/post.toml";
      description = "Private standalone TOML; mutable state resolves relative to this file.";
    };
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services.lamplit-post-console = {
      Unit = {
        Description = "Lamplit Post standalone settings";
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "exec";
        # ExecCondition provides a diagnostic and skips startup without a restart loop.
        ExecCondition = lib.escapeShellArgs ["${prepare}/bin/prepare-post-console" cfg.releaseRoot cfg.configFile];
        # Ignore absent cwd so ExecCondition can diagnose and skip an uninitialized app.
        WorkingDirectory = "-${cfg.releaseRoot}";
        ExecStartPre = lib.escapeShellArgs [node "${cfg.releaseRoot}/dist/cli.cjs" "config-check" "--config" cfg.configFile];
        ExecStart = lib.escapeShellArgs [node "${cfg.releaseRoot}/dist/cli.cjs" "serve" "--config" cfg.configFile];
        Environment = ["PATH=${lib.makeBinPath [pkgsUnstable.nodejs_24]}"];
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
