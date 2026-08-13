{
  pkgs,
  pkgsUnstable,
  ...
}: let
  npmPrefix = "/home/neil/.local/share/npm-global";
  inherit (pkgsUnstable) nodejs;
  installScript = pkgs.writeShellScript "openai-codex-install" ''
    set -eu

    export NPM_CONFIG_PREFIX=${npmPrefix}
    export PATH=${nodejs}/bin:${npmPrefix}/bin:/run/current-system/sw/bin:$PATH

    if command -v kosmos-wsl-proxy-env >/dev/null 2>&1; then
      eval "$(kosmos-wsl-proxy-env sh)"
    fi

    mkdir -p "${npmPrefix}"
    npm install -g @openai/codex@latest
  '';
in {
  environment.systemPackages = [
    nodejs
    (pkgs.writeShellScriptBin "openai-codex-install" ''
      exec ${installScript}
    '')
  ];
}
