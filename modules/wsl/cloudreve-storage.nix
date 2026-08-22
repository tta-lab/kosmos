{
  lib,
  pkgs,
  ...
}: let
  mountPoint = "/mnt/kosmos-cloudreve";
  diskUuid = "441ba8bb-d21b-40e4-a921-ef5553e07ff3";
in {
  fileSystems.${mountPoint} = {
    device = "/dev/disk/by-uuid/${diskUuid}";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # Never create the hostPath directories with tmpfiles: without the Micron
  # filesystem mounted, that would silently put Cloudreve data on the WSL root.
  systemd.services.cloudreve-storage = {
    description = "Prepare Cloudreve storage on the Micron data disk";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    path = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      while true; do
        mounted_uuid="$(findmnt --first-only --noheadings --raw --output UUID --target ${lib.escapeShellArg mountPoint} 2>/dev/null || true)"
        if [ "$mounted_uuid" = "${diskUuid}" ]; then
          install -d -m 0750 -o root -g root ${lib.escapeShellArg "${mountPoint}/cloudreve"}
          install -d -m 0750 -o root -g root ${lib.escapeShellArg "${mountPoint}/cloudreve/data"}
          # postgres:17-alpine runs its postgres account as uid/gid 70.
          install -d -m 0700 -o 70 -g 70 ${lib.escapeShellArg "${mountPoint}/cloudreve/postgres"}

          while [ "$(findmnt --first-only --noheadings --raw --output UUID --target ${lib.escapeShellArg mountPoint} 2>/dev/null || true)" = "${diskUuid}" ]; do
            sleep 30
          done
        else
          mount ${lib.escapeShellArg mountPoint} || true
          sleep 5
        fi
      done
    '';
  };
}
