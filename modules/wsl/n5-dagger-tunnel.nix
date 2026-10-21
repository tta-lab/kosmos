{
  lib,
  pkgs,
  ...
}: let
  topology = builtins.fromJSON (builtins.readFile ./proxy-topology.json);
in {
  # Retry until cni0 exists; never widen the listeners to a wildcard address.
  home-manager.users.neil.systemd.user.services.n5-dagger-tunnel = {
    Unit = {
      Description = "N5 Dagger SSH local forwards";
      StartLimitIntervalSec = 0;
    };
    Install.WantedBy = ["default.target"];
    Service = {
      Type = "exec";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.openssh}/bin/ssh"
        "-NT"
        "-F"
        "/dev/null"
        "-i"
        "/home/neil/.ssh/id_ed25519"
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "IdentityAgent=none"
        "-o"
        "BatchMode=yes"
        "-o"
        "StrictHostKeyChecking=yes"
        "-o"
        "UserKnownHostsFile=/home/neil/.ssh/known_hosts"
        "-o"
        "ExitOnForwardFailure=yes"
        "-o"
        "ConnectTimeout=10"
        "-o"
        "ConnectionAttempts=1"
        "-o"
        "ServerAliveInterval=15"
        "-o"
        "ServerAliveCountMax=3"
        "-o"
        "ControlMaster=no"
        "-o"
        "ControlPath=none"
        "-o"
        "ForwardAgent=no"
        "-o"
        "StdinNull=yes"
        "-L"
        "127.0.0.1:8080:127.0.0.1:8080"
        "-L"
        "${topology.podProxyHost}:8080:127.0.0.1:8080"
        "root@192.168.1.88"
      ];
      Restart = "always";
      RestartSec = "5s";
      KillMode = "control-group";
      TimeoutStopSec = "10s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
