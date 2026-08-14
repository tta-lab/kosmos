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
  proxyEnvironment = lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
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
in {
  environment = {
    sessionVariables = {
      GOPATH = goPath;
      GOBIN = goBin;
      GOMODCACHE = goModCache;
      GOCACHE = goCache;
      GOTELEMETRY = "off";
    };
  };

  users.users.neil.linger = true;

  home-manager.users.neil.systemd.user.services = {
    temenos = {
      Unit = {
        Description = "Temenos sandbox daemon";
        ConditionPathExists = "${goBin}/temenos";
      };
      Install.WantedBy = ["default.target"];
      Service = {
        ExecStart = "${goBin}/temenos daemon";
        Restart = "on-failure";
        Environment = serviceEnv ++ proxyEnvironment;
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
        ExecStart = "${goBin}/og daemon run";
        Restart = "on-failure";
        EnvironmentFile = "-/home/neil/.config/ttal/.env";
        Environment = serviceEnv ++ proxyEnvironment;
        WorkingDirectory = "/home/neil";
      };
    };
  };
}
