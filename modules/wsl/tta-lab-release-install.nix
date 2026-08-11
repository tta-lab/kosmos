{pkgs, ...}: let
  homeDirectory = "/home/neil";
  proxyUrl = "http://127.0.0.1:7890";
  noProxy = "localhost,127.0.0.1,::1";
  installScript = pkgs.writeShellApplication {
    name = "tta-lab-release-install";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnutar
      gnused
      jq
      systemd
      xz
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../../scripts/install-tta-lab-releases}
    '';
  };
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "tta-lab-release-install" ''
      exec systemctl --user start tta-lab-release-install.service
    '')
  ];

  home-manager.users.neil.systemd.user.services.tta-lab-release-install = {
    Unit.Description = "Install latest tta-lab release CLIs";
    Service = {
      Type = "oneshot";
      ExecStart = installScript;
      WorkingDirectory = homeDirectory;
      Environment = [
        "HOME=${homeDirectory}"
        "HTTP_PROXY=${proxyUrl}"
        "HTTPS_PROXY=${proxyUrl}"
        "ALL_PROXY=${proxyUrl}"
        "NO_PROXY=${noProxy}"
        "http_proxy=${proxyUrl}"
        "https_proxy=${proxyUrl}"
        "all_proxy=${proxyUrl}"
        "no_proxy=${noProxy}"
      ];
    };
  };
}
