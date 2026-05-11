{ pkgs, ... }:

let
  goBin = "/home/neil/go/bin";
  servicePath = "${goBin}:/run/current-system/sw/bin";
  installScript = pkgs.writeShellScript "tta-lab-go-install" ''
    set -eu

    export GOPATH=/home/neil/go
    export GOBIN=/home/neil/go/bin
    export PATH=${pkgs.go}/bin:${pkgs.git}/bin:${pkgs.openssh}/bin:/run/current-system/sw/bin:$PATH

    mkdir -p "$GOBIN"

    go install github.com/tta-lab/ttal-cli@latest
    go install github.com/tta-lab/temenos/cmd/temenos@latest
    go install github.com/tta-lab/diary/cmd/diary@latest
    go install github.com/tta-lab/organon/cmd/alert@latest
    go install github.com/tta-lab/organon/cmd/skill@latest
    go install github.com/tta-lab/organon/cmd/src@latest
    go install github.com/tta-lab/organon/cmd/web@latest
    go install github.com/tta-lab/einai@latest
    go install github.com/tta-lab/lenos@latest

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

  programs.fish.shellInit = ''
    fish_add_path -g ${goBin}
  '';

  users.users.neil.linger = true;

  systemd.user.services = {
    tta-lab-go-install = {
      description = "Install tta-lab Go CLIs into ~/go/bin";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = installScript;
        RemainAfterExit = true;
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
        ExecStart = "${goBin}/temenos daemon";
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
        ExecStart = "${goBin}/ei daemon run";
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
        ExecStart = "${goBin}/ttal daemon run";
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
