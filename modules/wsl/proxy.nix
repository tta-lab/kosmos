{
  config,
  lib,
  ...
}: let
  mihomoProxyUrl = "http://127.0.0.1:7890";
in {
  options.kosmos.wsl = {
    k3sProxyUrl = lib.mkOption {
      type = lib.types.str;
      default = mihomoProxyUrl;
      description = "HTTP proxy URL injected into K3s containerd environment (default: local Mihomo on 127.0.0.1:7890)";
    };
  };

  config = {
    environment.variables = {
      HTTP_PROXY = mihomoProxyUrl;
      HTTPS_PROXY = mihomoProxyUrl;
      ALL_PROXY = mihomoProxyUrl;
      NO_PROXY = "localhost,127.0.0.1,::1";
      http_proxy = mihomoProxyUrl;
      https_proxy = mihomoProxyUrl;
      all_proxy = mihomoProxyUrl;
      no_proxy = "localhost,127.0.0.1,::1";
    };
  };
}
