{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.postConsole;
  state = "/home/neil/.local/state/lamplit-post/console";
  prepare = pkgs.writeShellApplication {
    name = "prepare-post-console";
    runtimeInputs = [pkgs.coreutils pkgsUnstable.nodejs_24];
    text = builtins.readFile ../../scripts/prepare-post-console;
  };
in {
  options.kosmos.wsl.postConsole = {
    enable = lib.mkEnableOption "empty-account native Post Console preview";
    artifact = lib.mkOption {
      type = lib.types.str;
      default = "/home/neil/.local/share/lamplit-post/console-current";
      description = "Stable prefix pointing to the complete immutable Post Console release.";
    };
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services.lamplit-post-console = {
      Unit = {
        Description = "Lamplit Post native Console (VPN empty-account preview)";
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "exec";
        # ExecCondition provides a diagnostic and skips startup without a restart loop.
        ExecCondition = lib.escapeShellArgs ["${prepare}/bin/prepare-post-console" cfg.artifact state];
        StateDirectory = "lamplit-post/console";
        StateDirectoryMode = "0700";
        WorkingDirectory = state;
        ExecStart = lib.escapeShellArgs [(lib.getExe pkgsUnstable.nodejs_24) "${cfg.artifact}/dist/cli.cjs" "serve" "--config" "${state}/koishi.yml"];
        Environment = ["PATH=${lib.makeBinPath [pkgsUnstable.nodejs_24 pkgs.coreutils]}"];
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
