{
  lib,
  pkgs,
  ...
}: {
  # SW's two loopback listeners share one foreground connection over OpenVPN.
  home-manager.users.neil.systemd.user.services.sw-build-tunnel = {
    Unit = {
      Description = "SW Dagger and Mihomo SSH reverse tunnel";
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
        "/home/neil/.ssh/seafarer_prod_ed25519"
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
        "-R"
        "127.0.0.1:18080:127.0.0.1:8080"
        "-R"
        "127.0.0.1:17890:127.0.0.1:7890"
        "sw-admin@192.168.6.186"
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
