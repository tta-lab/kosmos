{ ... }:

{
  imports = [
    ./disko-config.nix
    ./modules/system.nix
    ./modules/networking.nix
    ./modules/proxy.nix
    ./modules/users.nix
    ./modules/packages.nix
    ./modules/firewall.nix
  ];
}
