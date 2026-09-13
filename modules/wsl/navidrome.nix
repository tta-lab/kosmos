{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.navidrome;
in {
  options.kosmos.wsl.navidrome = {
    enable = lib.mkEnableOption "Navidrome music server for kosmos-wsl";

    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = /mnt/kosmos-cloudreve/navidrome/music;
      description = "Local music library path exposed read-only to Navidrome.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.navidrome = {
      enable = true;
      user = "neil";
      group = "users";

      settings = {
        Address = "127.0.0.1";
        Port = 4533;
        DataFolder = "/mnt/kosmos-cloudreve/navidrome/data";
        CacheFolder = "/mnt/kosmos-cloudreve/navidrome/cache";
        MusicFolder = "/music";
        EnableDownloads = false;
        EnableSharing = false;
        EnableInsightsCollector = false;
      };
    };

    systemd.services.navidrome = {
      after = ["cloudreve-storage.service"];
      requires = ["cloudreve-storage.service"];
      serviceConfig.BindReadOnlyPaths =
        lib.mkForce
        ([
            "${config.security.pki.caBundle}:/etc/ssl/certs/ca-certificates.crt"
            builtins.storeDir
            "/etc"
            "${toString cfg.musicFolder}:/music"
          ]
          ++ lib.optionals config.services.resolved.enable [
            "/run/systemd/resolve/stub-resolv.conf"
            "/run/systemd/resolve/resolv.conf"
          ]);
    };
  };
}
