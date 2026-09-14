{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.codexForLove;
  checkout = "/home/neil/code/projects/lamplitisles/codex-for-love";
  node = lib.getExe pkgsUnstable.nodejs_24;
  service = {
    name,
    partnerName,
    port,
  }: let
    stateRoot = "/home/neil/.local/state/codex-for-love/${name}";
    configFile = "${stateRoot}/partner.toml";
    start = pkgs.writeShellScript "codex-for-love-${name}-start" ''
            set -eu

            if [ ! -r ${lib.escapeShellArg configFile} ]; then
              echo "codex-for-love-${name}: missing operator configuration ${configFile}" >&2
              exit 1
            fi
            while IFS= read -r expected; do
              if ! ${pkgs.gnugrep}/bin/grep -Fqx "$expected" ${lib.escapeShellArg configFile}; then
                echo "codex-for-love-${name}: configuration is missing required setting: $expected" >&2
                exit 1
              fi
            done <<'EOF'
      name = "${partnerName}"
      persona = "${stateRoot}/persona.md"
      state = "${stateRoot}/state"
      workspace = "${stateRoot}/workspace"
      port = ${toString port}
      model = "gpt-5.6-luna"
      home = "/home/neil/.codex"
      EOF
            exec ${node} ${lib.escapeShellArg "${checkout}/apps/partner/runtime/cli.ts"} serve ${lib.escapeShellArg configFile}
    '';
  in {
    Unit = {
      Description = "Codex for Love ${name} Partner";
      After = ["network-online.target"];
    };
    Install.WantedBy = ["default.target"];
    Service = {
      WorkingDirectory = checkout;
      ExecStartPre = lib.escapeShellArgs [
        "${pkgs.coreutils}/bin/install"
        "-d"
        "-m"
        "0700"
        stateRoot
      ];
      ExecStart = start;
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
      Environment = [
        "HOME=/home/neil"
        "PATH=/home/neil/.local/bin:/run/current-system/sw/bin"
      ];
    };
  };
in {
  options.kosmos.wsl.codexForLove.enable = lib.mkEnableOption "isolated Codex for Love Partner services";

  config = lib.mkIf cfg.enable {
    home-manager.users.neil.systemd.user.services = {
      codex-for-love-dev = service {
        name = "dev";
        partnerName = "Mika";
        port = 3082;
      };
      codex-for-love-prod = service {
        name = "prod";
        partnerName = "Shio";
        port = 3084;
      };
    };
  };
}
