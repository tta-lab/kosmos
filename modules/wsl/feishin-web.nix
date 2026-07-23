{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.kosmos.wsl.feishinWeb;
  keposCloudflaredCredentialsFile = ../../secrets/cloudflared-kepos-credentials.age;
  haveKeposTunnel =
    config.kosmos.wsl ? keposTunnel
    && config.kosmos.wsl.keposTunnel.enable
    && builtins.pathExists keposCloudflaredCredentialsFile;

  settingsJs = pkgs.writeText "feishin-settings.js" ''
    "use strict";

    window.SERVER_URL = "${cfg.musicServerUrl}";
    window.REMOTE_URL = "https://${cfg.publicHostname}";
    window.LISTEN_TOGETHER_URL = "${cfg.listenTogetherUrl}";
    window.LISTEN_TOGETHER_ENABLED = "${lib.boolToString cfg.listenTogetherEnabled}";
    window.SERVER_NAME = "${cfg.serverName}";
    window.SERVER_TYPE = "subsonic";
    window.SERVER_LOCK = "true";
    window.LEGACY_AUTHENTICATION = "false";
    window.ANALYTICS_DISABLED = "true";

    window.FS_GENERAL_LANGUAGE = "zh-Hans";
    window.FS_GENERAL_THEME = "defaultDark";
    window.FS_GENERAL_THEME_DARK = "defaultDark";
    window.FS_GENERAL_THEME_LIGHT = "defaultLight";
    window.FS_PLAYBACK_MEDIA_SESSION = "true";
    window.FS_PLAYBACK_WEB_AUDIO = "true";
  '';

  webRoot = pkgs.runCommand "feishin-web-root" {} ''
    mkdir -p "$out"
    cp -r ${cfg.package}/share/feishin-web/. "$out/"
    cp ${settingsJs} "$out/settings.js"
  '';

  serverConfig = pkgs.writeText "feishin-web-static-server.toml" ''
    [general]
    host = "127.0.0.1"
    port = ${toString cfg.port}
    root = "${webRoot}"
    cache-control-headers = false

    [advanced]

    [[advanced.headers]]
    source = "/assets/*-*.{js,css,map,woff,woff2,png,svg,webp}"
    [advanced.headers.headers]
    Cache-Control = "public, max-age=31536000, immutable"

    [[advanced.headers]]
    source = "/index.html"
    [advanced.headers.headers]
    Cache-Control = "no-store"

    [[advanced.headers]]
    source = "/settings.js"
    [advanced.headers.headers]
    Cache-Control = "no-store"

    [[advanced.headers]]
    source = "/assets/sw.js"
    [advanced.headers.headers]
    Cache-Control = "no-store"

    [[advanced.headers]]
    source = "/assets/manifest.webmanifest"
    [advanced.headers.headers]
    Cache-Control = "no-store"
  '';
in {
  options.kosmos.wsl.feishinWeb = {
    enable = lib.mkEnableOption "Feishin web client for Navidrome";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgsUnstable.callPackage ../../packages/feishin-web {};
      description = "Feishin web static asset package.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9180;
      description = "Local Feishin web HTTP port.";
    };

    publicHostname = lib.mkOption {
      type = lib.types.str;
      default = "player.guion.io";
      description = "Public hostname exposed through the Kepos Cloudflare tunnel.";
    };

    musicServerUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://music.guion.io";
      description = "Navidrome server URL preconfigured in Feishin.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "Kepos Music";
      description = "Display name for the preconfigured Navidrome server.";
    };

    listenTogetherUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://party.guion.io";
      description = "Listen Together sidecar URL preconfigured in Feishin.";
    };

    listenTogetherEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether new Feishin browser profiles should enable Listen Together by default.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.mkIf (!haveKeposTunnel) [
        ''
          Feishin Web is enabled without the kepos Cloudflare tunnel.
          It will listen locally only until kosmos.wsl.keposTunnel is enabled and secrets/cloudflared-kepos-credentials.age exists.
        ''
      ];

      systemd.services.feishin-web = {
        description = "Feishin web client";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          DynamicUser = true;
          ExecStart = "${lib.getExe pkgs.static-web-server} --config-file ${serverConfig}";
          Restart = "on-failure";
          RestartSec = "5s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };
    }

    (lib.mkIf haveKeposTunnel {
      services.cloudflared.tunnels.kepos.ingress.${cfg.publicHostname} = "http://127.0.0.1:${toString cfg.port}";
    })
  ]);
}
