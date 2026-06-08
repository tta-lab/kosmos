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
  windowsProxyEnable = config.kosmos.wsl.windowsProxy.enable or false;
  mihomoProxyUrl = config.kosmos.wsl.mihomoProxyUrl or "http://127.0.0.1:7890";
  proxyPrelude =
    if windowsProxyEnable
    then ''
      if command -v kosmos-wsl-proxy-env >/dev/null 2>&1; then
        eval "$(kosmos-wsl-proxy-env sh)"
      fi
    ''
    else ''
      export HTTP_PROXY=${mihomoProxyUrl}
      export HTTPS_PROXY=${mihomoProxyUrl}
      export ALL_PROXY=${mihomoProxyUrl}
      export NO_PROXY=localhost,127.0.0.1,::1
    '';
  goEnv = [
    "GOROOT=${pkgsUnstable.go}/share/go"
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

    export GOROOT=${pkgsUnstable.go}/share/go
    export GOPATH=${goPath}
    export GOBIN=${goBin}
    export GOMODCACHE=${goModCache}
    export GOCACHE=${goCache}
    export GOTELEMETRY=off
    export PATH=${servicePath}:$PATH
    ${proxyPrelude}

    mkdir -p "$GOBIN"

    kosmos-sync-tta-lab-projects

    install_from() {
      repo="$1"
      shift
      dir="${projectsRoot}/$repo"
      if [ ! -f "$dir/go.mod" ]; then
        echo "missing Go module: $dir" >&2
        exit 1
      fi

      (
        cd "$dir"
        go install "$@"
      )
    }

    build_from() {
      repo="$1"
      binary="$2"
      package="$3"
      dir="${projectsRoot}/$repo"
      if [ ! -f "$dir/go.mod" ]; then
        echo "missing Go module: $dir" >&2
        exit 1
      fi

      (
        cd "$dir"
        go build -o "$GOBIN/$binary" "$package"
      )
    }

    build_from ttal-cli ttal .
    rm -f "$GOBIN/ttal-cli"
    install_from temenos ./cmd/temenos
    install_from diary ./cmd/diary
    install_from organon ./cmd/skill ./cmd/src ./cmd/web
    install_from einai .
    install_from lenos .

    [ -x "$GOBIN/einai" ] && ln -sf "$GOBIN/einai" "$GOBIN/ei"
  '';
in {
  environment = {
    sessionVariables = {
      GOROOT = "${pkgsUnstable.go}/share/go";
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

    einai = {
      Unit = {
        Description = "Einai agent runtime daemon";
        After = ["temenos.service"];
        ConditionPathExists = "${goBin}/ei";
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = withProxy "einai-with-proxy" "${goBin}/ei daemon run";
        Restart = "on-failure";
        Environment = serviceEnv;
        WorkingDirectory = "/home/neil";
      };
    };

    ttal = {
      Unit = {
        Description = "TTAL coordination daemon";
        After = [
          "einai.service"
          "temenos.service"
        ];
        ConditionPathExists = "${goBin}/ttal";
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = withProxy "ttal-with-proxy" "${goBin}/ttal daemon run";
        Restart = "on-failure";
        Environment = serviceEnv;
        WorkingDirectory = "/home/neil";
      };
    };
  };
}
