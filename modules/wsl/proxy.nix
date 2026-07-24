{
  config,
  lib,
  ...
}: let
  windowsProxyUrl = "http://127.0.0.1:7897";
in {
  options.kosmos.wsl = {
    k3sProxyUrl = lib.mkOption {
      type = lib.types.str;
      default = windowsProxyUrl;
      description = "HTTP proxy URL injected into K3s containerd environment (default: Windows-side proxy on 127.0.0.1:7897)";
    };
  };

  config = {
    environment.variables = {
      HTTP_PROXY = windowsProxyUrl;
      HTTPS_PROXY = windowsProxyUrl;
      ALL_PROXY = windowsProxyUrl;
      NO_PROXY = "localhost,127.0.0.1,::1";
      http_proxy = windowsProxyUrl;
      https_proxy = windowsProxyUrl;
      all_proxy = windowsProxyUrl;
      no_proxy = "localhost,127.0.0.1,::1";
    };
  };
}
