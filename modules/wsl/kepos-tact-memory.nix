{
  config,
  lib,
  ...
}: let
  executable = "/home/neil/.local/bin/kepos-tact-memory";
  configFile = "/home/neil/.config/kepos/tact-memory.toml";
in {
  # Runtime service unit for the Tact remote-memory daemon.
  #
  # The server configuration at configFile is deliberately NOT managed here:
  # it is a hand-maintained runtime artifact (git- and nix-untracked), so local
  # bearer credentials and device bindings never enter the repository. The unit
  # only pins the executable and the config path; a missing config file fails
  # startup loudly instead of silently falling back to defaults. See
  # kepos-tact-memory/config.example.toml for the supported shape.
  home-manager.users.neil = {
    systemd.user.services.kepos-tact-memory = {
      Unit = {
        Description = "Kepos Tact remote memory (SQLite)";
        After = ["network-online.target"];
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "simple";
        WorkingDirectory = "/home/neil";
        ExecStartPre = ["test -f ${lib.escapeShellArg configFile}"];
        ExecStart = lib.escapeShellArgs [executable "--config" configFile];
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
