_: {
  imports = [
    ../../modules/common/nix.nix
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
    ../../modules/wsl/frpc-ssh.nix
    ../../modules/wsl/secrets.nix
    ../../modules/wsl/mihomo.nix
    ../../modules/wsl/proxy.nix
    ../../modules/wsl/k3s.nix
    ../../modules/wsl/cloudreve-storage.nix
    ../../modules/wsl/kepos-neo.nix
    ../../modules/wsl/kepos-codex-bridge.nix
    ../../modules/wsl/kepos-tunnel.nix
    ../../modules/wsl/navidrome.nix
    ../../modules/wsl/deepseek-harness.nix
    ../../modules/wsl/apt-cacher-ng.nix
    ../../modules/wsl/openvpn.nix
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
    frpcSsh.enable = true;
    keposTunnel.enable = true;
    mihomo.enable = true;
    navidrome.enable = true;
    deepseekHarness.enable = true;
  };
  system.stateVersion = "25.05";
}
