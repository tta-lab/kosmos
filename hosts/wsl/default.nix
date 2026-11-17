_: {
  imports = [
    ../../modules/common/nix.nix
    ../../modules/wsl/nix-gc.nix
    ../../modules/common/system.nix
    ../../modules/common/packages.nix
    ../../modules/common/rust.nix
    ../../modules/common/codex.nix
    ../../modules/common/pi.nix
    ../../modules/common/tta-lab-go.nix
    ../../modules/common/shell.nix
    ../../modules/common/ssh.nix
    ../../modules/common/tunnel-rathole-client.nix
    ../../modules/users/neil.nix
    ../../modules/wsl
    ../../modules/wsl/secrets.nix
    ../../modules/wsl/mihomo.nix
    ../../modules/wsl/proxy.nix
    ../../modules/wsl/k3s.nix
    ../../modules/wsl/http-gateway.nix
    ../../modules/wsl/android-development.nix
    ../../modules/wsl/cloudreve-storage.nix
    ../../modules/wsl/kepos-neo.nix
    ../../modules/wsl/kepos-tunnel.nix
    ../../modules/wsl/codex-for-love.nix
    ../../modules/wsl/matrix-mcp-remote.nix
    ../../modules/wsl/keet-mcp.nix
    ../../modules/wsl/lamplit-post-console.nix
    ../../modules/wsl/flickgrove.nix
    ../../modules/wsl/apt-cacher-ng.nix
    ../../modules/wsl/n5-dagger-tunnel.nix
    ../../modules/wsl/sw-build-tunnel.nix
    ../../modules/wsl/openvpn.nix
    ../../modules/wsl/openai-tunnel.nix
    ../../modules/configs.nix
  ];

  networking.hostName = "kosmos-wsl";
  services.openssh.listenAddresses = [
    {
      addr = "0.0.0.0";
      port = 22;
    }
    {
      addr = "[::]";
      port = 22;
    }
  ];
  kosmos.wsl = {
    keposTunnel.enable = false;
    mihomo.enable = true;
    codexForLove.enable = false;
    flickgrove.enable = false;
    keposPeer.enable = false;
    n5DaggerTunnel.enable = false;
    openaiTunnel.enable = false;
    postConsole.enable = false;
    keetMcp.enable = false;
    matrixMcpRemote.enable = false;
    swBuildTunnel.enable = false;
  };
  systemd.services.cloudflared-tunnel-kepos.enable = false;
  system.stateVersion = "25.05";
}
