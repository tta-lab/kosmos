{
  config,
  lib,
  ...
}: {
  home-manager.users.neil.systemd.user.services.flickgrove = {
    Unit = {
      Description = "FlickGrove fixed Hub";
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    Install.WantedBy = ["default.target"];
    Service = {
      Type = "exec";
      WorkingDirectory = "/home/neil/code/projects/lamplitisles/experiments/flickgrove";
      ExecStart = lib.escapeShellArgs [
        "/run/current-system/sw/bin/bun"
        "/home/neil/code/projects/lamplitisles/experiments/flickgrove/server/main.ts"
        "--hub"
        "--name"
        "ko"
        "--listen"
        "127.0.0.1"
        "--port"
        "4318"
        "--origin"
        "http://flickgrove.localhost:17480"
        "--state"
        "/home/neil/.local/share/flickgrove"
        "--codex"
        "/home/neil/.local/share/npm-global/bin/codex"
      ];
      Environment =
        [
          "PATH=/run/current-system/sw/bin:/home/neil/.local/bin:/home/neil/go/bin:/home/neil/.local/share/npm-global/bin:/home/neil/.cargo/bin"
        ]
        ++ lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = "5s";
      KillMode = "mixed";
      TimeoutStopSec = "60s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
