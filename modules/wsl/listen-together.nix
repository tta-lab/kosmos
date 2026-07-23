{
  config,
  lib,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.listenTogether;
  effectiveAllowedOrigins =
    if cfg.allowedOrigins == []
    then [
      "https://${cfg.publicHostname}"
      "https://music.guion.io"
    ]
    else cfg.allowedOrigins;
in {
  options.kosmos.wsl.listenTogether = {
    enable = lib.mkEnableOption "Listen Together sync service for Navidrome";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgsUnstable.callPackage ../../packages/listen-together {};
      description = "listen-together package to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4040;
      description = "Local HTTP/WebSocket port for listen-together.";
    };

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "party.guion.io";
      description = "Public hostname exposed through the Kepos Cloudflare tunnel.";
    };

    allowedServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["https://music.guion.io"];
      description = "Subsonic/Navidrome server URLs accepted for authentication.";
    };

    allowedOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Browser origins accepted for WebSocket upgrades. Empty uses the public listen-together hostname and music.guion.io.";
    };

    maxRooms = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 20;
      description = "Maximum concurrent listen-together rooms. Zero disables the cap.";
    };

    maxMembersPerRoom = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 12;
      description = "Maximum members per listen-together room. Zero disables the cap.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.listen-together = {
      description = "Listen Together sync service";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        LT_PORT = toString cfg.port;
        LT_ALLOWED_SERVERS = lib.concatStringsSep "," cfg.allowedServers;
        LT_ALLOWED_ORIGINS = lib.concatStringsSep "," effectiveAllowedOrigins;
        LT_MAX_ROOMS = toString cfg.maxRooms;
        LT_MAX_MEMBERS_PER_ROOM = toString cfg.maxMembersPerRoom;
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };
  };
}
