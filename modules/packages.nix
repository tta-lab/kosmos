{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Editor
    helix
    # Shell
    fish
    bash
    # Dev tools
    git
    tmux
    ripgrep
    fd
    bat
    jq
    fzf
    direnv
    httpie
    wget
    curl
    # Languages
    bun
    go
    python3
    # Containers
    podman
    # Monitor
    btop
    bottom
    htop
    # Proxy
    mihomo
    # Misc
    tree
    gnugrep
    gnused
    gawk
    # Nix tooling
    nh
    comma
    nix-direnv
    statix
    nixd
  ];

  programs = {
    fish = {
      enable = true;
      shellAliases = {
        vi = "hx";
      };
    };

    mosh.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    tmux = {
      enable = true;
      terminal = "screen-256color";
      # TODO: Neil to drop .tmux.conf into ~ or use extraTmuxConfig
      # extraTmuxConfig = builtins.readFile ./tmux.conf;
    };
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };
}
