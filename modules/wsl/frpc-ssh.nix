{
  config,
  lib,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.frpcSsh;
in {
  options.kosmos.wsl.frpcSsh = {
    enable = lib.mkEnableOption "frpc SSH tunnel for kosmos-wsl";

    serverAddr = lib.mkOption {
      type = lib.types.str;
      description = "frps server address.";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "frps server bind port.";
    };

    remotePort = lib.mkOption {
      type = lib.types.port;
      description = "Remote TCP port exposed on the frps server for SSH.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.frpc-token = {
      file = ../../secrets/frpc-token.age;
      owner = "frp";
      group = "frp";
      mode = "0400";
    };

    users.groups.frp = {};
    users.users.frp = {
      isSystemUser = true;
      group = "frp";
    };

    services.frp = {
      enable = true;
      role = "client";
      package = pkgsUnstable.frp;
      settings = {
        inherit (cfg) serverAddr serverPort;
        auth = {
          method = "token";
          tokenSource = {
            type = "file";
            file.path = config.age.secrets.frpc-token.path;
          };
        };
        proxies = [
          {
            name = "kosmos-wsl-ssh";
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = 22;
            inherit (cfg) remotePort;
          }
        ];
      };
    };

    systemd.services.frp.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "frp";
      Group = "frp";
    };
  };
}
