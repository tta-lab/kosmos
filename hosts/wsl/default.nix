_: {
  imports = [
    ../../modules/common/nix.nix
    ../../modules/common/system.nix
    ../../modules/common/packages.nix
    ../../modules/common/rust.nix
    ../../modules/common/codex.nix
    ../../modules/common/tta-lab-go.nix
    ../../modules/common/shell.nix
    ../../modules/common/ssh.nix
    ../../modules/common/tunnel-rathole-client.nix
    ../../modules/users/neil.nix
    ../../modules/wsl
    ../../modules/wsl/frpc-ssh.nix
    ../../modules/wsl/secrets.nix
    ../../modules/wsl/apt-cacher-ng.nix
    ../../modules/configs.nix
  ];

  networking.hostName = "kosmos-wsl";
  services.openssh.listenAddresses = [
    {
      addr = "127.0.0.1";
      port = 22;
    }
    {
      addr = "::1";
      port = 22;
    }
  ];
  kosmos.wsl.frpcSsh.enable = true;
  system.stateVersion = "25.05";
}
