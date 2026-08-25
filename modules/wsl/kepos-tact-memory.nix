{
  config,
  lib,
  ...
}: let
  executable = "/home/neil/.local/bin/kepos-tact-memory";
  serverPort = 8788;
  stateDir = "/home/neil/.local/state/kepos-tact-memory";
  configFile = "/home/neil/.config/kepos/tact-memory.toml";

  # Device→namespace bindings. A namespace is a person or team; one person's
  # several devices share one namespace, and each device stays bound to exactly
  # one namespace. Mirrors kepos/publisher-policy.jsonnet allowlists.
  # role: "writer" (default) or "reader".
  bindings = [
    {
      namespace = "neil";
      role = "writer";
      # mac (operator's MacBook; subscriber key from kepos/publisher-policy.jsonnet)
      keys = ["c5a2168e17a53b699ced7e3f3c8470afd7f91b97a1582076c9797c3e024311a2"];
    }
  ];

  renderBinding = b: ''
    [[auth.bindings]]
    namespace = "${b.namespace}"
    ${
      if b.role == "reader"
      then "role = \"reader\""
      else ""
    }
    keys = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') b.keys}]
  '';
in {
  home-manager.users.neil.systemd.user.services.kepos-tact-memory = {
    Unit = {
      Description = "Kepos Tact remote memory (SQLite)";
      After = ["network-online.target"];
    };
    Install.WantedBy = ["default.target"];
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/neil";
      ExecStart = lib.escapeShellArgs [executable "--config" configFile];
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  # Server policy: the binding table (public keys only, no secrets).
  home.file."${configFile}" = {
    text =
      ''
        [server]
        bind = "127.0.0.1:${toString serverPort}"
        db = "${stateDir}/memory.sqlite3"
      ''
      + lib.concatMapStringsSep "" renderBinding bindings;
    mode = "0600";
  };
}
