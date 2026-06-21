{
  hermes-agent,
  pkgs,
  ...
}: let
  hermesPackages = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system};
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
    # Upstream bundles a plugin named "cron"; that shadows the Python cron
    # dependency and breaks gateway startup under the Nix wrapper.
    package = hermesGateway;
    addToSystemPackages = true;
  };
}
