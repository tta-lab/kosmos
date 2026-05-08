{ config, pkgs, ... }:

{
  # Phase 1: LAN proxy via Mac's clash verge
  # Replace <mac-ip> with actual Mac LAN IP at install time
  # Find via `ipconfig getifaddr en0` on the Mac
  networking.proxy.default = "http://<mac-ip>:7890";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal";

  # Phase 2 scaffold: mihomo as local service (disabled until mihomo config exists)
  # systemd.services.mihomo = {
  #   description = "Mihomo (Clash Meta) Proxy";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.mihomo}/bin/mihomo -d /etc/mihomo";
  #     Restart = "on-failure";
  #     DynamicUser = true;
  #   };
  # };
}
