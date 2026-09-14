{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.codexForLove;
  checkout = "/home/neil/code/projects/lamplitisles/codex-for-love";
  checkoutCommit = "17542aee587779e795b149f17311473b65ebf3d2";
  artifactDirectory = "/home/neil/.local/share/codex-for-love/artifacts/codex-0.154.0";
  node = lib.getExe pkgsUnstable.nodejs_24;
  pnpm = "${pkgsUnstable.callPackage ../../packages/pnpm {}}/bin/pnpm";
  service = {
    name,
    port,
  }: let
    stateRoot = "/home/neil/.local/state/codex-for-love/${name}";
    configFile = "${stateRoot}/partner.toml";
    start = pkgs.writeShellScript "codex-for-love-${name}-start" ''
      set -eu

      actual_commit="$(${pkgs.git}/bin/git -C ${lib.escapeShellArg checkout} rev-parse HEAD)"
      if [ "$actual_commit" != ${lib.escapeShellArg checkoutCommit} ]; then
        echo "codex-for-love-${name}: expected CFL ${checkoutCommit}, got $actual_commit" >&2
        exit 1
      fi
      for artifact in codex codex.provenance.json codex-code-mode-host; do
        if [ ! -r ${lib.escapeShellArg artifactDirectory}/"$artifact" ]; then
          echo "codex-for-love-${name}: missing artifact $artifact in ${artifactDirectory}" >&2
          exit 1
        fi
      done
      if [ ! -r ${lib.escapeShellArg configFile} ]; then
        echo "codex-for-love-${name}: missing operator configuration ${configFile}" >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fqx ${lib.escapeShellArg "port = ${toString port}"} ${lib.escapeShellArg configFile}; then
        echo "codex-for-love-${name}: configuration must bind fixed port ${toString port}" >&2
        exit 1
      fi
      exec ${node} ${pnpm} --dir ${lib.escapeShellArg checkout} --filter @lamplitisles/partner cli serve ${lib.escapeShellArg configFile}
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
        port = 3082;
      };
      codex-for-love-prod = service {
        name = "prod";
        port = 3084;
      };
    };
  };
}
