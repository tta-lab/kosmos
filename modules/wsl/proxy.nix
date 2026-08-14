{
  config,
  lib,
  ...
}: let
  topology = builtins.fromJSON (builtins.readFile ./proxy-topology.json);
  localEndpoint = "${topology.listener.host}:${toString topology.listener.port}";
  podEndpoint = "${topology.podProxyHost}:${toString topology.listener.port}";
  cfg = config.kosmos.wsl.proxy;
  noProxy = lib.concatStringsSep "," cfg.noProxy;
  proxyEnvironment = {
    HTTP_PROXY = cfg.url;
    HTTPS_PROXY = cfg.url;
    ALL_PROXY = cfg.url;
    NO_PROXY = noProxy;
    http_proxy = cfg.url;
    https_proxy = cfg.url;
    all_proxy = cfg.url;
    no_proxy = noProxy;
  };
  shellEnvironment = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") proxyEnvironment
  );
in {
  options.kosmos.wsl.proxy = {
    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "HTTP proxy URL for the local Mihomo listener";
    };

    noProxy = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Base addresses that bypass the local HTTP proxy";
    };

    localEndpoint = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Local Mihomo listener endpoint";
    };

    podEndpoint = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Mihomo endpoint reachable from k3s Pods";
    };

    podCidr = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "k3s Pod CIDR";
    };

    serviceCidr = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "k3s Service CIDR";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Canonical upper- and lowercase HTTP proxy environment variables";
    };
  };

  config = {
    kosmos.wsl.proxy = {
      url = "http://${localEndpoint}";
      noProxy = topology.baseNoProxy;
      inherit localEndpoint podEndpoint;
      inherit (topology) podCidr serviceCidr;
      environment = proxyEnvironment;
    };

    networking.proxy = {
      default = cfg.url;
      inherit noProxy;
    };

    environment = {
      variables = proxyEnvironment;
      etc."kosmos/proxy.env".text = "${shellEnvironment}\n";
    };
  };
}
