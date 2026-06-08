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
      tunMode = false;
    };

    environment.variables = {
      HTTP_PROXY = lib.mkIf (!cfg.enable) "http://127.0.0.1:7890";
      HTTPS_PROXY = lib.mkIf (!cfg.enable) "http://127.0.0.1:7890";
      ALL_PROXY = lib.mkIf (!cfg.enable) "http://127.0.0.1:7890";
      NO_PROXY = lib.mkIf (!cfg.enable) "localhost,127.0.0.1,::1";
      http_proxy = lib.mkIf (!cfg.enable) "http://127.0.0.1:7890";
      https_proxy = lib.mkIf (!cfg.enable) "http://127.0.0.1:7890";
      all_proxy = lib.mkIf (!cfg.enable) "http://127.0.0.1:7890";
      no_proxy = lib.mkIf (!cfg.enable) "localhost,127.0.0.1,::1";
    };
  };
}
