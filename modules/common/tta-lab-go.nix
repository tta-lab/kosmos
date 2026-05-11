{ pkgs, ... }:

let
  goBin = "/home/neil/go/bin";
  servicePath = "${goBin}:/run/current-system/sw/bin";
  proxyPrelude = ''
    if command -v kosmos-wsl-proxy-env >/dev/null 2>&1; then
      eval "$(kosmos-wsl-proxy-env sh)"
    fi
  '';
  withProxy = name: command: pkgs.writeShellScript name ''
    set -eu
    export PATH=/run/current-system/sw/bin:${servicePath}:$PATH
    ${proxyPrelude}
    exec ${command}
  '';
  installScript = pkgs.writeShellScript "tta-lab-go-install" ''
    set -eu

    export GOPATH=/home/neil/go
    export GOBIN=/home/neil/go/bin
    export PATH=${pkgs.go}/bin:${pkgs.git}/bin:${pkgs.openssh}/bin:/run/current-system/sw/bin:$PATH
    ${proxyPrelude}

    mkdir -p "$GOBIN"

    go install github.com/tta-lab/ttal-cli@main
    go install github.com/tta-lab/temenos/cmd/temenos@main
    go install github.com/tta-lab/diary/cmd/diary@main
    go install github.com/tta-lab/organon/cmd/alert@main
    go install github.com/tta-lab/organon/cmd/skill@main
    go install github.com/tta-lab/organon/cmd/src@main
    go install github.com/tta-lab/organon/cmd/web@main
    go install github.com/tta-lab/einai@main
    go install github.com/tta-lab/lenos@main

    [ -x "$GOBIN/ttal-cli" ] && ln -sf "$GOBIN/ttal-cli" "$GOBIN/ttal"
    [ -x "$GOBIN/einai" ] && ln -sf "$GOBIN/einai" "$GOBIN/ei"
  '';
in
{
  environment = {
    variables = {
      GOPATH = "/home/neil/go";
      GOBIN = goBin;
    };

    systemPackages = [
      (pkgs.writeShellScriptBin "tta-lab-go-install" ''
        exec systemctl --user start tta-lab-go-install.service
      '')
    ];
  };

  users.users.neil.linger = true;

  systemd.user.services = {
    tta-lab-go-install = {
      description = "Install tta-lab Go CLIs into ~/go/bin";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = installScript;
      };
    };

    temenos = {
      description = "Temenos sandbox daemon";
      wantedBy = [ "default.target" ];
      unitConfig.ConditionPathExists = "${goBin}/temenos";
      path = with pkgs; [
        bash
        bubblewrap
        coreutils
        git
        go
        openssh
      ];
      serviceConfig = {
        ExecStart = withProxy "temenos-with-proxy" "${goBin}/temenos daemon";
        Restart = "on-failure";
        Environment = [
          "HOME=/home/neil"
          "PATH=${servicePath}"
        ];
        WorkingDirectory = "/home/neil";
      };
    };

    einai = {
      description = "Einai agent runtime daemon";
      wantedBy = [ "default.target" ];
      after = [ "temenos.service" ];
      unitConfig.ConditionPathExists = "${goBin}/ei";
      path = with pkgs; [
        bash
        coreutils
        git
        go
        openssh
        tmux
      ];
      serviceConfig = {
        ExecStart = withProxy "einai-with-proxy" "${goBin}/ei daemon run";
        Restart = "on-failure";
        Environment = [
          "HOME=/home/neil"
          "PATH=${servicePath}"
        ];
        WorkingDirectory = "/home/neil";
      };
    };

    ttal = {
      description = "TTAL coordination daemon";
      wantedBy = [ "default.target" ];
      after = [
        "einai.service"
        "temenos.service"
      ];
      unitConfig.ConditionPathExists = "${goBin}/ttal";
      path = with pkgs; [
        bash
        coreutils
        git
        go
        openssh
        tmux
      ];
      serviceConfig = {
        ExecStart = withProxy "ttal-with-proxy" "${goBin}/ttal daemon run";
        Restart = "on-failure";
        Environment = [
          "HOME=/home/neil"
          "PATH=${servicePath}"
        ];
        WorkingDirectory = "/home/neil";
      };
    };
  };
}
