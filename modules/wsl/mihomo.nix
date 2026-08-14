{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.kosmos.wsl.mihomo;
  inherit (config.kosmos.wsl) proxy;
  prepareMihomoConfig = pkgs.writeShellApplication {
    name = "kosmos-prepare-mihomo-config";
    runtimeInputs = [pkgs.yq];
    text = builtins.readFile ../../scripts/prepare-mihomo-config;
  };
in {
  options.kosmos.wsl.mihomo = {
    enable = lib.mkEnableOption "local Mihomo proxy using the Clash Verge runtime configuration";

    configFile = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/c/Users/white/AppData/Roaming/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml";
      description = "Clash Verge generated runtime configuration loaded by the Mihomo systemd service";
    };
  };

  config = lib.mkIf cfg.enable {
    services.mihomo = {
      enable = true;
      inherit (cfg) configFile;
      tunMode = false;
      webui = pkgs.metacubexd;
    };

    systemd = {
      services.mihomo.serviceConfig = {
        ExecStartPre = "${prepareMihomoConfig}/bin/kosmos-prepare-mihomo-config \${CREDENTIALS_DIRECTORY}/config.yaml \${RUNTIME_DIRECTORY}/config.yaml";
        ExecStart = lib.mkForce "${lib.getExe config.services.mihomo.package} -d /var/lib/private/mihomo -f \${RUNTIME_DIRECTORY}/config.yaml -ext-ui ${config.services.mihomo.webui}";
        RuntimeDirectory = "mihomo-runtime";
        RuntimeDirectoryMode = "0700";
        Restart = "on-failure";
      };

      sockets.mihomo-cni-proxy = {
        description = "Mihomo proxy listener for k3s Pods";
        wantedBy = ["sockets.target"];
        listenStreams = [proxy.podEndpoint];
        socketConfig.FreeBind = true;
      };

      services.mihomo-cni-proxy = {
        description = "Forward k3s Pod proxy traffic to Mihomo";
        requires = ["mihomo.service"];
        after = ["mihomo.service"];
        serviceConfig.ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${proxy.localEndpoint}";
      };
    };
  };
}
