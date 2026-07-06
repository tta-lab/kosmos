{pkgs, ...}: let
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
  daggerEngineIsolationSmoke = pkgs.writeScriptBin "kosmos-dagger-engine-isolation-smoke" (builtins.readFile ../../scripts/dagger-engine-isolation-smoke);
  daggerEngineConfigSmoke = pkgs.writeScriptBin "kosmos-dagger-engine-config-smoke" (builtins.readFile ../../scripts/dagger-engine-config-smoke);
  daggerLocalRegistrySmoke = pkgs.writeScriptBin "kosmos-dagger-local-registry-smoke" (builtins.readFile ../../scripts/dagger-local-registry-smoke);
  daggerLargeRegistrySmoke = pkgs.writeScriptBin "kosmos-dagger-large-registry-smoke" (builtins.readFile ../../scripts/dagger-large-registry-smoke);
  daggerUnixSocketSmoke = pkgs.writeScriptBin "kosmos-dagger-unix-socket-smoke" (builtins.readFile ../../scripts/dagger-unix-socket-smoke);
  dataDiskPreflight = pkgs.writeScriptBin "kosmos-data-disk-preflight" (builtins.readFile ../../scripts/data-disk-preflight);
  devopsGateStatus = pkgs.writeScriptBin "kosmos-devops-gate-status" (builtins.readFile ../../scripts/devops-gate-status);
  devopsSmoke = pkgs.writeScriptBin "kosmos-wsl-devops-smoke" (builtins.readFile ../../scripts/wsl-devops-smoke);
  forgejoBackupReplicate = pkgs.writeScriptBin "kosmos-forgejo-backup-replicate" (builtins.readFile ../../scripts/forgejo-backup-replicate);
  forgejoBackupSmoke = pkgs.writeScriptBin "kosmos-forgejo-backup-smoke" (builtins.readFile ../../scripts/forgejo-backup-smoke);
  forgejoCutoverPreflight = pkgs.writeScriptBin "kosmos-forgejo-cutover-preflight" (builtins.readFile ../../scripts/forgejo-cutover-preflight);
  forgejoDumpRestoreSmoke = pkgs.writeScriptBin "kosmos-forgejo-dump-restore-smoke" (builtins.readFile ../../scripts/forgejo-dump-restore-smoke);
  forgejoHttpsGitSmoke = pkgs.writeScriptBin "kosmos-forgejo-https-git-smoke" (builtins.readFile ../../scripts/forgejo-https-git-smoke);
  forgejoK8sPullSecretSmoke = pkgs.writeScriptBin "kosmos-forgejo-k8s-pull-secret-smoke" (builtins.readFile ../../scripts/forgejo-k8s-pull-secret-smoke);
  forgejoMigrationDryRun = pkgs.writeScriptBin "kosmos-forgejo-migration-dry-run" (builtins.readFile ../../scripts/forgejo-migration-dry-run);
  forgejoRestoreSmoke = pkgs.writeScriptBin "kosmos-forgejo-restore-smoke" (builtins.readFile ../../scripts/forgejo-restore-smoke);
  woodpeckerDaggerJobSmoke = pkgs.writeScriptBin "kosmos-woodpecker-dagger-job-smoke" (builtins.readFile ../../scripts/woodpecker-dagger-job-smoke);
  woodpeckerPreflight = pkgs.writeScriptBin "kosmos-woodpecker-preflight" (builtins.readFile ../../scripts/woodpecker-preflight);
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
      daggerLocalRegistrySmoke
      daggerEngineIsolationSmoke
      daggerEngineConfigSmoke
      daggerLargeRegistrySmoke
      daggerUnixSocketSmoke
      dataDiskPreflight
      devopsGateStatus
      docker-compose
      devopsSmoke
      forgejo
      forgejoBackupReplicate
      forgejoBackupSmoke
      forgejoCutoverPreflight
      forgejoDumpRestoreSmoke
      forgejoHttpsGitSmoke
      forgejoK8sPullSecretSmoke
      forgejoMigrationDryRun
      forgejoRestoreSmoke
      k3d
      proxyEnv
      woodpecker-cli
      woodpeckerDaggerJobSmoke
      woodpeckerPreflight
    ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  virtualisation.containers.registries.insecure = [
    "127.0.0.1:3000"
    "10.88.0.1:3000"
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
