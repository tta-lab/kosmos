{ pkgs, ... }:

let
  npmPrefix = "/home/neil/.local/share/npm-global";
  installScript = pkgs.writeShellScript "openai-codex-install" ''
    set -eu

    export NPM_CONFIG_PREFIX=${npmPrefix}
    export PATH=${pkgs.nodejs}/bin:${npmPrefix}/bin:/run/current-system/sw/bin:$PATH

    if command -v kosmos-wsl-proxy-env >/dev/null 2>&1; then
      eval "$(kosmos-wsl-proxy-env sh)"
    fi

    mkdir -p "${npmPrefix}"
    npm install -g @openai/codex@latest
  '';
in
{
  environment.systemPackages = [
    pkgs.nodejs
    (pkgs.writeShellScriptBin "openai-codex-install" ''
      exec systemctl --user start openai-codex-install.service
    '')
  ];

  home-manager.users.neil.systemd.user.services.openai-codex-install = {
    Unit.Description = "Install OpenAI Codex CLI with npm";
    Service = {
      Type = "oneshot";
      ExecStart = installScript;
    };
  };
}
