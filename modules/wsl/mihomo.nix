{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.windowsProxy;
  mihomoProxy = "http://127.0.0.1:7890";
in {
  options.kosmos.wsl = {
    windowsProxy.enable = lib.mkEnableOption "Windows-host HTTP proxy as fallback (default: local mihomo systemd service)";
    mihomoProxyUrl = lib.mkOption {
      type = lib.types.str;
      default = mihomoProxy;
      description = "Local mihomo proxy URL used for HTTP_PROXY/HTTPS_PROXY when windowsProxy is disabled";
    };
  };

  config = {
    services.mihomo = {
      enable = true;
      configFile = config.age.secrets.mihomo-config.path;
      tunMode = false;
    };

    environment.variables = lib.mkIf (!cfg.enable) {
      HTTP_PROXY = config.kosmos.wsl.mihomoProxyUrl;
      HTTPS_PROXY = config.kosmos.wsl.mihomoProxyUrl;
      ALL_PROXY = config.kosmos.wsl.mihomoProxyUrl;
      NO_PROXY = "localhost,127.0.0.1,::1";
      http_proxy = config.kosmos.wsl.mihomoProxyUrl;
      https_proxy = config.kosmos.wsl.mihomoProxyUrl;
      all_proxy = config.kosmos.wsl.mihomoProxyUrl;
      no_proxy = "localhost,127.0.0.1,::1";
    };
  };
}
