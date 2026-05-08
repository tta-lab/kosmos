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
      terminal = "tmux-256color";
      extraConfig = builtins.readFile ../tmux/.tmux.conf;
    };
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };
}
