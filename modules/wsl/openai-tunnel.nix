{
  config,
  lib,
  pkgs,
  ...
}: let
  version = "0.0.14";
  archive = pkgs.fetchzip {
    url = "https://github.com/openai/tunnel-client/releases/download/v${version}/tunnel-client-v${version}-linux-amd64.zip";
    hash = "sha256-6TsVfsh452wmMmPoGP68MCB+4MfIyML68y1syzQVYLc=";
    stripRoot = false;
  };
  tunnelClient = pkgs.stdenvNoCC.mkDerivation {
    pname = "tunnel-client";
    inherit version;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 ${archive}/tunnel-client $out/bin/tunnel-client
      install -Dm755 ${archive}/cloudflared $out/bin/cloudflared
      runHook postInstall
    '';
    meta = {
      description = "OpenAI Secure MCP Tunnel client";
      homepage = "https://github.com/openai/tunnel-client";
      license = lib.licenses.asl20;
      mainProgram = "tunnel-client";
      platforms = ["x86_64-linux"];
    };
  };
  secretPath =
    if config.age.secrets ? "openai-tunnel.env"
    then config.age.secrets."openai-tunnel.env".path
    else "/run/agenix/openai-tunnel.env";
  proxyEnvironment = lib.mapAttrsToList (name: value: "${name}=${value}") config.kosmos.wsl.proxy.environment;
in {
  home-manager.users.neil = {
    home.packages = [tunnelClient];

    xdg.configFile."tunnel-client/og.yaml".text = ''
      config_version: 1
      control_plane:
        base_url: "https://api.openai.com"
        tunnel_id: "tunnel_6ab4d54f12208191b16ea0495b73098c"
        api_key: "env:CONTROL_PLANE_API_KEY"
      health:
        listen_addr: "127.0.0.1:0"
      admin_ui:
        open_browser: false
      log:
        level: info
        format: json
      mcp:
        commands:
          - channel: main
            command: "/home/neil/go/bin/og mcp"
    '';

    systemd.user.services.openai-og-tunnel = {
      Unit = {
        Description = "OpenAI Secure MCP Tunnel for Organon";
        After = ["network-online.target"];
        ConditionPathExists = [
          "/home/neil/go/bin/og"
          secretPath
        ];
      };
      Install.WantedBy = ["default.target"];
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe tunnelClient} run --profile og";
        Restart = "always";
        RestartSec = 5;
        Environment =
          [
            "HOME=/home/neil"
            "PATH=/home/neil/go/bin:/run/current-system/sw/bin"
          ]
          ++ proxyEnvironment;
        EnvironmentFile = secretPath;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
