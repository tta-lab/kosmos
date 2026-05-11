{ ... }:

{
  imports = [
    ../../disko-config.nix
    ../../modules/common/nix.nix
    ../../modules/common/system.nix
    ../../modules/common/packages.nix
    ../../modules/common/shell.nix
    ../../modules/common/ssh.nix
    ../../modules/common/tunnel-rathole-client.nix
    ../../modules/users/neil.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/proxy.nix
    ../../modules/nixos/firewall.nix
    ../../modules/nixos/containers.nix
  ];

  system.stateVersion = "25.05";
}
