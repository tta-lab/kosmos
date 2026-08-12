{
  pkgs,
  pkgsUnstable,
  ...
}: let
  npmPrefix = "/home/neil/.local/share/npm-global";
  inherit (pkgsUnstable) nodejs;
  installScript = pkgs.writeShellScript "pi-install" ''
    set -eu

    export NPM_CONFIG_PREFIX=${npmPrefix}
    export PATH=${nodejs}/bin:${npmPrefix}/bin:/run/current-system/sw/bin:$PATH

    if command -v kosmos-wsl-proxy-env >/dev/null 2>&1; then
      eval "$(kosmos-wsl-proxy-env sh)"
    fi

    mkdir -p "${npmPrefix}"
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest
    pi install npm:mitsupi
    pi install npm:pi-mcp-adapter
    pi install npm:pi-herdr-subagents
    herdr integration install pi
  '';
in {
  environment.systemPackages = [
    nodejs
    (pkgs.writeShellScriptBin "pi-install" ''
      exec ${installScript}
    '')
  ];
}
