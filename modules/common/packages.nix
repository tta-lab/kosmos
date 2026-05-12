{pkgs, ...}: let
  ttaLab = pkgs.callPackage ../../packages/tta-lab {};
  syncProjects = pkgs.writeShellApplication {
    name = "kosmos-sync-projects";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${../../scripts/sync-projects} "$@"
    '';
  };
  syncTtaLabProjects = pkgs.writeShellApplication {
    name = "kosmos-sync-tta-lab-projects";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
    ];
    text = ''
      exec ${syncProjects}/bin/kosmos-sync-projects \
        --alias diary \
        --alias ei \
        --alias len \
        --alias orga \
        --alias temenos \
        --alias ttal \
        "$@"
    '';
  };
  ttalTmuxProjectPicker = pkgs.writeShellApplication {
    name = "ttal-tmux-project-picker";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.fzf
      pkgs.gawk
      pkgs.gnused
      pkgs.jq
      pkgs.tmux
    ];
    text = ''
      export PATH=/home/neil/go/bin:$PATH
      exec ${pkgs.bash}/bin/bash ${../../scripts/ttal-tmux-project-picker} "$@"
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    # Shells and editors
    helix
    fish
    bash

    # Core tools
    openssh
    git
    git-filter-repo
    git-lfs
    git-sizer
    delta
    tmux
    gnumake

    # Search and data handling
    ripgrep
    fd
    bat
    jq
    yq
    sqlite
    fzf
    direnv
    yazi

    # Network and HTTP
    httpie
    wget
    curl
    dnsutils
    mtr
    nmap
    tcpdump
    socat
    lsof
    traceroute
    whois

    # Secrets and task helpers
    age
    sops
    just
    syncProjects
    syncTtaLabProjects
    ttalTmuxProjectPicker
    ttaLab.flicknote
    ttaLab.taskwarrior

    # Languages
    bun
    go
    python3

    # System inspection
    btop
    eza
    duf
    dust
    gdu
    ncdu

    # Tunnels and ingress
    mihomo
    rathole
    cloudflared
    caddy

    # Cloud and Kubernetes
    gh
    hcloud
    kubectl
    tanka
    jsonnet-bundler
    kubectx
    kubelogin
    kubernetes-helm
    helm-ls
    k9s
    lazygit

    # GNU and Nix tooling
    tree
    gnugrep
    gnused
    gawk
    nh
    nix-output-monitor
    nvd
    deadnix
    alejandra
    comma
    nix-direnv
    statix
    nixd
  ];
}
