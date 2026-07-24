{
  pkgs,
  pkgsUnstable,
  ...
}: let
  proxyEnv = pkgs.writeShellApplication {
    name = "kosmos-wsl-proxy-env";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      gawk
      iproute2
    ];
    text = ''
      set -eu

      mode="''${1:-sh}"
      port="''${KOSMOS_WSL_PROXY_PORT:-7897}"
      host="''${KOSMOS_WSL_PROXY_HOST:-}"

      if [ -z "$host" ]; then
        if timeout 1 bash -c ":</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
          host="127.0.0.1"
        fi
      fi

      if [ -z "$host" ]; then
        host="$(ip route show default 2>/dev/null | awk '/^default[[:space:]]+/ { print $3; exit }')"
      fi

      if [ -z "$host" ] && [ -r /etc/resolv.conf ]; then
        host="$(awk '/^nameserver[[:space:]]+/ && $2 !~ /^(127\.|::1$)/ { print $2; exit }' /etc/resolv.conf)"
      fi

      if [ -z "$host" ]; then
        exit 0
      fi

      if ! timeout 1 bash -c ":</dev/tcp/$host/$port" 2>/dev/null; then
        exit 0
      fi

      proxy_url="http://$host:$port"
      no_proxy="localhost,127.0.0.1,::1,$host"

      case "$mode" in
        fish)
          printf 'set -gx HTTP_PROXY "%s"\n' "$proxy_url"
          printf 'set -gx HTTPS_PROXY "%s"\n' "$proxy_url"
          printf 'set -gx ALL_PROXY "%s"\n' "$proxy_url"
          printf 'set -gx NO_PROXY "%s"\n' "$no_proxy"
          printf 'set -gx http_proxy "%s"\n' "$proxy_url"
          printf 'set -gx https_proxy "%s"\n' "$proxy_url"
          printf 'set -gx all_proxy "%s"\n' "$proxy_url"
          printf 'set -gx no_proxy "%s"\n' "$no_proxy"
          ;;
        sh)
          printf 'export HTTP_PROXY="%s"\n' "$proxy_url"
          printf 'export HTTPS_PROXY="%s"\n' "$proxy_url"
          printf 'export ALL_PROXY="%s"\n' "$proxy_url"
          printf 'export NO_PROXY="%s"\n' "$no_proxy"
          printf 'export http_proxy="%s"\n' "$proxy_url"
          printf 'export https_proxy="%s"\n' "$proxy_url"
          printf 'export all_proxy="%s"\n' "$proxy_url"
          printf 'export no_proxy="%s"\n' "$no_proxy"
          ;;
        env)
          printf 'HTTP_PROXY=%s\n' "$proxy_url"
          printf 'HTTPS_PROXY=%s\n' "$proxy_url"
          printf 'ALL_PROXY=%s\n' "$proxy_url"
          printf 'NO_PROXY=%s\n' "$no_proxy"
          printf 'http_proxy=%s\n' "$proxy_url"
          printf 'https_proxy=%s\n' "$proxy_url"
          printf 'all_proxy=%s\n' "$proxy_url"
          printf 'no_proxy=%s\n' "$no_proxy"
          ;;
        *)
          echo "usage: kosmos-wsl-proxy-env [sh|fish|env]" >&2
          exit 2
          ;;
      esac
    '';
  };
  cloudflaredIngressSmoke = pkgs.writeScriptBin "kosmos-cloudflared-ingress-smoke" (builtins.readFile ../../scripts/cloudflared-ingress-smoke);
  devopsGateStatus = pkgs.writeScriptBin "kosmos-devops-gate-status" (builtins.readFile ../../scripts/devops-gate-status);
  devopsSmoke = pkgs.writeScriptBin "kosmos-wsl-devops-smoke" (builtins.readFile ../../scripts/wsl-devops-smoke);
  forgejoK8sPullSecretSmoke = pkgs.writeScriptBin "kosmos-forgejo-k8s-pull-secret-smoke" (builtins.readFile ../../scripts/forgejo-k8s-pull-secret-smoke);
in {
  wsl = {
    enable = true;
    defaultUser = "neil";

    interop = {
      includePath = false;
    };

    wslConf = {
      interop.appendWindowsPath = false;
    };
  };

  environment = {
    systemPackages = with pkgs; [
      cloudflaredIngressSmoke
      devopsGateStatus
      devopsSmoke
      forgejoK8sPullSecretSmoke
      proxyEnv
      rsync
    ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  virtualisation.containers.registries.insecure = [
    "host.containers.internal:3000"
  ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      openssl
      sqlite
      stdenv.cc.cc
      zlib
    ];
  };
}
