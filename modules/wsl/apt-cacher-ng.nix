{pkgs, ...}: {
  systemd.services.apt-cacher-ng = {
    description = "apt-cacher-ng package proxy cache";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      ExecStart =
        "${pkgs.apt-cacher-ng}/bin/apt-cacher-ng"
        + " ForeGround=1"
        + " BindAddress=0.0.0.0"
        + " Port=3142"
        + " CacheDir=/var/cache/apt-cacher-ng"
        + " LogDir=/var/log/apt-cacher-ng";
      Restart = "on-failure";
      CacheDirectory = "apt-cacher-ng";
      LogsDirectory = "apt-cacher-ng";
    };
  };

  networking.firewall.allowedTCPPorts = [3142];
}
