{
  kepos-neo,
  lib,
  ...
}: let
  package = kepos-neo.packages.x86_64-linux.kepos;
  dashboardPackage = kepos-neo.packages.x86_64-linux.grafana-dashboard;
  peerStateDir = "/home/neil/.local/state/kepos-neo/peer";
  # Unmanaged runtime output, rendered atomically from the Jsonnet source.
  # Identity conversion is an operator cutover step, never an activation hook.
  peerPolicyFile = "/home/neil/.config/kepos/peer.toml";
in {
  home-manager.users.neil = {
    home.packages = [package];
    systemd.user.services.kepos-peer = {
      Unit = {
        Description = "Kepos peer";
        After = ["network-online.target"];
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe package)
          "peer"
          "run"
          "--state"
          peerStateDir
          "--config"
          peerPolicyFile
          "--observations"
          "ndjson"
          "--metrics-listen"
          "10.255.255.1:9475"
        ];
        Restart = "always";
        RestartSec = 5;
        KillMode = "mixed";
        TimeoutStopSec = 15;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };

  # Kubernetes mounts the dashboard from this stable system-profile path.
  environment.systemPackages = [dashboardPackage];
  environment.pathsToLink = ["/share/kepos"];
}
