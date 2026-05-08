
  # Packages
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
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  programs.fish.shellAliases = {
    vi = "hx";
  };
}
