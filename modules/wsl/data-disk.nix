{
  config,
  lib,
  ...
}: let
  cfg = config.kosmos.wsl.dataDisk;
in {
  options.kosmos.wsl.dataDisk = {
    enable = lib.mkEnableOption "optional NUC data disk mount for WSL services";

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nuc-data";
      description = "Mount point for the NUC data disk.";
    };

    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/disk/by-uuid/bf1ab97f-1d98-4977-89ed-58a8d0098e6c";
      description = "Block device for the data disk. Prefer a stable /dev/disk/by-uuid path.";
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "ext4";
      description = "Filesystem type for the data disk.";
    };

    options = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
      description = "Mount options for the data disk.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.device != null;
        message = "kosmos.wsl.dataDisk.device must be set when kosmos.wsl.dataDisk.enable is true.";
      }
    ];

    fileSystems.${cfg.mountPoint} = {
      inherit (cfg) device fsType options;
      neededForBoot = false;
    };
  };
}
