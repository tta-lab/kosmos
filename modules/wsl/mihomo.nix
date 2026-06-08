{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.windowsProxy;
in {
  options.kosmos.wsl.windowsProxy.enable = lib.mkEnableOption "Windows-host HTTP proxy as fallback (default: local mihomo systemd service)";

  config = {
    services.mihomo = {
      enable = true;
      configFile = config.age.secrets.mihomo-config.path;
      tunMode = true;
    };
  };
}
