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
  service = {
    name,
    partnerName,
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
            for artifact in codex codex-code-mode-host; do
              if [ ! -x ${lib.escapeShellArg artifactDirectory}/"$artifact" ]; then
                echo "codex-for-love-${name}: artifact $artifact must be executable in ${artifactDirectory}" >&2
                exit 1
              fi
            done
            if [ ! -r ${lib.escapeShellArg "${artifactDirectory}/codex.provenance.json"} ]; then
              echo "codex-for-love-${name}: missing artifact provenance in ${artifactDirectory}" >&2
              exit 1
            fi
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
      command = "${artifactDirectory}/codex"
      provenance = "${artifactDirectory}/codex.provenance.json"
      model = "gpt-5.6-luna"
      version = "0.154.0"
      home = "/home/neil/.codex"
      local_compaction = true
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
