{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  goPath = "/home/neil/go";
  goBin = "${goPath}/bin";
  goModCache = "${goPath}/pkg/mod";
  goCache = "/home/neil/.cache/go-build";
  projectsRoot = "/home/neil/code/projects/tta-lab";
  servicePath = "${goBin}:${pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.bubblewrap
    pkgs.coreutils
    pkgs.gcc
    pkgs.git
    pkgsUnstable.go
    pkgs.openssh
    pkgs.tmux
  ]}:/run/current-system/sw/bin";
  proxyPrelude = ''
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
    export ALL_PROXY=http://127.0.0.1:7890
    export NO_PROXY=localhost,127.0.0.1,::1
  '';
  goEnv = [
    "GOPATH=${goPath}"
    "GOBIN=${goBin}"
    "GOMODCACHE=${goModCache}"
    "GOCACHE=${goCache}"
    "GOTELEMETRY=off"
  ];
  serviceEnv =
    goEnv
    ++ [
      "HOME=/home/neil"
      "PATH=${servicePath}"
    ];
  withProxy = name: command:
    pkgs.writeShellScript name ''
      set -eu
      export PATH=/run/current-system/sw/bin:${servicePath}:$PATH
      ${proxyPrelude}
      exec ${command}
    '';
  installScript = pkgs.writeShellScript "tta-lab-go-install" ''
    set -eu

    export GOPATH=${goPath}
    export GOBIN=${goBin}
    export GOMODCACHE=${goModCache}
    export GOCACHE=${goCache}
    export GOTELEMETRY=off
    export PATH=${servicePath}:$PATH
    ${proxyPrelude}

    mkdir -p "$GOBIN"
    export TTA_LAB_PROJECTS_ROOT=${projectsRoot}
    exec ${pkgs.bash}/bin/bash ${../../scripts/install-tta-lab-go}
  '';
in {
  environment = {
    sessionVariables = {
      GOPATH = goPath;
      GOBIN = goBin;
      GOMODCACHE = goModCache;
      GOCACHE = goCache;
      GOTELEMETRY = "off";
    };

    systemPackages = [
      (pkgs.writeShellScriptBin "tta-lab-go-install" ''
        exec systemctl --user start tta-lab-go-install.service
      '')
    ];
  };

  users.users.neil.linger = true;

  home-manager.users.neil.systemd.user.services = {
    tta-lab-go-install = {
      Unit.Description = "Install tta-lab Go CLIs into ~/go/bin";
      Service = {
        Type = "oneshot";
        ExecStart = installScript;
      };
    };

    temenos = {
      Unit = {
        Description = "Temenos sandbox daemon";
        ConditionPathExists = "${goBin}/temenos";
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = withProxy "temenos-with-proxy" "${goBin}/temenos daemon";
        Restart = "on-failure";
        Environment = serviceEnv;
        WorkingDirectory = "/home/neil";
      };
    };

    og = {
      Unit = {
        Description = "Organon forge operations daemon";
        ConditionPathExists = "${goBin}/og";
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = withProxy "og-with-proxy" "${goBin}/og daemon run";
        Restart = "on-failure";
        EnvironmentFile = "-/home/neil/.config/ttal/.env";
        Environment =
          serviceEnv
          ++ [
            "HTTP_PROXY=http://127.0.0.1:7890"
            "HTTPS_PROXY=http://127.0.0.1:7890"
            "ALL_PROXY=http://127.0.0.1:7890"
            "NO_PROXY=localhost,127.0.0.1,::1"
          ];
        WorkingDirectory = "/home/neil";
      };
    };
  };
}
