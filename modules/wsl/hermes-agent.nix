{pkgs, ...}: let
  hermesHome = "/home/neil/.hermes";
  hermesCheckout = "${hermesHome}/hermes-agent";
  hermesBin = "${hermesCheckout}/venv/bin/hermes";
  installHermes = pkgs.writeShellScript "install-hermes-agent" ''
    set -eu

    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT

    export HOME=/home/neil
    export HERMES_HOME=${hermesHome}
    export PATH=/home/neil/.local/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.xz}/bin:/run/current-system/sw/bin:$PATH

    curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$installer"
    ${pkgs.bash}/bin/bash "$installer" --skip-setup
  '';
  serviceEnvironment = [
    "HOME=/home/neil"
    "HERMES_HOME=${hermesHome}"
  ];
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "hermes-agent-install" ''
      exec ${installHermes}
    '')
  ];

  home-manager.users.neil = {
    home.sessionPath = ["/home/neil/.local/bin"];

    systemd.user.services.hermes-dashboard = {
      Unit = {
        Description = "Hermes Agent dashboard";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
        ConditionFileIsExecutable = hermesBin;
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = "${hermesBin} dashboard --host 127.0.0.1 --port 9119 --no-open";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = serviceEnvironment;
        WorkingDirectory = "/home/neil";
      };
    };
  };
}
