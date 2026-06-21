{
  hermes-agent,
  pkgs,
  ...
}: let
  hermesPackages = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system};
  inherit (hermesPackages.messaging.passthru) hermesVenv;
  hermesPluginsWithoutCron = pkgs.runCommand "hermes-agent-plugins-without-cron" {} ''
    mkdir -p "$out"
    cp -R --no-preserve=mode,ownership ${hermesPackages.messaging}/share/hermes-agent/plugins/. "$out/"
    rm -rf "$out/cron"
  '';
  hermesGateway = pkgs.runCommand "hermes-agent-gateway" {} ''
    cp -R --no-preserve=mode,ownership ${hermesPackages.messaging} "$out"
    chmod -R u+w "$out/bin"
    chmod +x "$out/bin/hermes" "$out/bin/hermes-agent" "$out/bin/hermes-acp"
    substituteInPlace "$out/bin/hermes" "$out/bin/hermes-agent" "$out/bin/hermes-acp" \
      --replace-fail "export HERMES_BUNDLED_PLUGINS='${hermesPackages.messaging}/share/hermes-agent/plugins'" \
                     "export HERMES_BUNDLED_PLUGINS='${hermesPluginsWithoutCron}'"
    substituteInPlace "$out/bin/hermes" \
      --replace-fail 'exec "${hermesVenv}/bin/hermes"  "$@"' \
                     'exec "${hermesVenv}/bin/python3" -c "import sys; import cron.scheduler_provider; from hermes_cli.main import main; sys.argv[0] = \"hermes\"; raise SystemExit(main())" "$@"'
    substituteInPlace "$out/bin/hermes-agent" \
      --replace-fail 'exec "${hermesVenv}/bin/hermes-agent"  "$@"' \
                     'exec "${hermesVenv}/bin/python3" -c "import sys; import cron.scheduler_provider; from hermes_cli.main import main; sys.argv[0] = \"hermes-agent\"; raise SystemExit(main())" "$@"'
    substituteInPlace "$out/bin/hermes-acp" \
      --replace-fail 'exec "${hermesVenv}/bin/hermes-acp"  "$@"' \
                     'exec "${hermesVenv}/bin/python3" -c "import sys; import cron.scheduler_provider; from hermes_cli.main import main; sys.argv[0] = \"hermes-acp\"; raise SystemExit(main())" "$@"'
  '';
in {
  imports = [
    hermes-agent.nixosModules.default
  ];

  environment.systemPackages = [
    hermesGateway
    hermesPackages.tui
  ];

  services.hermes-agent = {
    enable = true;
    # Upstream bundles a plugin named "cron"; it shadows the Python cron
    # dependency during gateway startup. Preload the dependency before plugin
    # discovery runs, and hide the bundled cron plugin directory.
    package = hermesGateway;
    addToSystemPackages = true;
  };
}
