{
  lib,
  pkgs,
  ...
}: let
  gascityHome = "/home/neil/.local/share/gascity";
  gascityCity = "${gascityHome}/city";
  gascityGitConfig = "${gascityHome}/gitconfig";
  bootstrapCityConfig = pkgs.writeText "gascity-city.toml" ''
    [workspace]
  '';

  dolt = pkgs.stdenvNoCC.mkDerivation {
    pname = "dolt";
    version = "2.2.3";

    src = pkgs.fetchurl {
      url = "https://github.com/dolthub/dolt/releases/download/v2.2.3/dolt-linux-amd64.tar.gz";
      hash = "sha256-/6+nzBcsraX3fKP7ljBlRd2sRKERYl91+HAwbH8ZcwE=";
    };
    dontUnpack = true;

    installPhase = ''
      ${pkgs.gnutar}/bin/tar -xzf "$src"
      ${pkgs.coreutils}/bin/install -Dm755 dolt-linux-amd64/bin/dolt "$out/bin/dolt"
    '';

    meta.mainProgram = "dolt";
  };

  gascity = pkgs.stdenvNoCC.mkDerivation {
    pname = "gascity";
    version = "1.4.0";

    src = pkgs.fetchurl {
      url = "https://github.com/gastownhall/gascity/releases/download/v1.4.0/gascity_1.4.0_linux_amd64.tar.gz";
      hash = "sha256-9r0L+vKswUFkIidik5TdMnl2HfThgAI1VRryTZi5yuA=";
    };
    dontUnpack = true;

    installPhase = ''
      ${pkgs.gnutar}/bin/tar -xzf "$src"
      ${pkgs.coreutils}/bin/install -Dm755 gc "$out/bin/gc"
    '';

    meta.mainProgram = "gc";
  };

  beads = pkgs.stdenvNoCC.mkDerivation {
    pname = "beads";
    version = "1.1.0";

    src = pkgs.fetchurl {
      url = "https://github.com/gastownhall/beads/releases/download/v1.1.0/beads_1.1.0_linux_amd64.tar.gz";
      hash = "sha256-sPPdYHw/uYnuCNCmhU+6gNBAKXHrEI+a9hcLwU1JGjQ=";
    };
    dontUnpack = true;

    installPhase = ''
      ${pkgs.gnutar}/bin/tar -xzf "$src"
      ${pkgs.coreutils}/bin/install -Dm755 bd "$out/bin/bd"
    '';

    meta.mainProgram = "bd";
  };

  runtimePackages = [
    gascity
    beads
    dolt
    pkgs.git
    pkgs.jq
    pkgs.lsof
    pkgs.procps
    pkgs.tmux
    pkgs.util-linux
  ];
  servicePath = lib.makeBinPath runtimePackages;
  prepareGitConfig = pkgs.writeShellScript "gascity-prepare-git-config" ''
    set -euo pipefail

    if test ! -e ${lib.escapeShellArg gascityGitConfig}; then
      ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg gascityHome}
      ${pkgs.git}/bin/git config --file ${lib.escapeShellArg gascityGitConfig} include.path /home/neil/.config/git/config
    fi
  '';
  runtimeEnvironment = [
    "HOME=/home/neil"
    "GC_HOME=${gascityHome}"
    "GIT_CONFIG_GLOBAL=${gascityGitConfig}"
    "GC_SUPERVISOR_SYSTEMD_UNIT=gascity.service"
    "GC_SUPERVISOR_SYSTEMD_SCOPE=user"
    "GC_SUPERVISOR_LOG_TEE=0"
    "PATH=${servicePath}:/run/current-system/sw/bin"
  ];
in {
  environment = {
    sessionVariables = {
      GC_HOME = gascityHome;
      GC_SUPERVISOR_SYSTEMD_UNIT = "gascity.service";
      GC_SUPERVISOR_SYSTEMD_SCOPE = "user";
      GC_SUPERVISOR_LOG_TEE = "0";
      GIT_CONFIG_GLOBAL = gascityGitConfig;
    };
    systemPackages =
      runtimePackages
      ++ [
        (pkgs.writeShellApplication {
          name = "gascity-init-kosmos";
          runtimeInputs = runtimePackages;
          text = ''
            export HOME=/home/neil
            export GC_HOME=${gascityHome}
            export GC_SUPERVISOR_SYSTEMD_UNIT=gascity.service
            export GC_SUPERVISOR_SYSTEMD_SCOPE=user
            export GC_SUPERVISOR_LOG_TEE=0
            export GIT_CONFIG_GLOBAL=${gascityGitConfig}
            unset GC_DOLT_HOST GC_DOLT_PORT GC_DOLT_USER GC_DOLT_DATABASE GC_BEADS_PROJECT_ID

            ${prepareGitConfig}

            if test -e ${lib.escapeShellArg "${gascityCity}/city.toml"}; then
              echo "Gas City is already initialized at ${gascityCity}" >&2
              exit 1
            fi

            exec ${gascity}/bin/gc init --file ${bootstrapCityConfig} --name kosmos --no-start ${lib.escapeShellArg gascityCity}
          '';
        })
        (pkgs.writeShellApplication {
          name = "gascity-start-kosmos";
          runtimeInputs = runtimePackages;
          text = ''
            export HOME=/home/neil
            export GC_HOME=${gascityHome}
            export GC_SUPERVISOR_SYSTEMD_UNIT=gascity.service
            export GC_SUPERVISOR_SYSTEMD_SCOPE=user
            export GC_SUPERVISOR_LOG_TEE=0
            export GIT_CONFIG_GLOBAL=${gascityGitConfig}

            ${prepareGitConfig}
            exec ${gascity}/bin/gc --city ${lib.escapeShellArg gascityCity} start "$@"
          '';
        })
      ];
  };

  home-manager.users.neil.systemd.user.services.gascity = {
    Unit = {
      Description = "Gas City supervisor";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Install.WantedBy = ["default.target"];
    Service = {
      ExecStartPre = "${prepareGitConfig}";
      ExecStart = "${gascity}/bin/gc supervisor run";
      Restart = "always";
      RestartSec = 5;
      KillMode = "process";
      Environment = runtimeEnvironment;
      WorkingDirectory = "/home/neil";
    };
  };
}
