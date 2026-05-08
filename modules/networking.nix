{ config, pkgs, ... }:

{
  networking.hostName = "kosmos";

  systemd.network.enable = true;
  systemd.network.networks."50-enp" = {
    matchConfig.Name = "enp*s0";
    networkConfig.DHCP = "yes";
  };
}
