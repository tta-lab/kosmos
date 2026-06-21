{
  hermes-agent,
  pkgs,
  ...
}: let
  hermesPackages = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = [
    hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = true;
    package = hermesPackages.messaging;
    addToSystemPackages = true;
  };
}
