{
  config,
  pkgs,
  pkgsUnstable,
  ...
}: let
  ttalBinDir = pkgs.lib.attrByPath ["environment" "variables" "GOBIN"] null config;
  ttaLab = pkgs.callPackage ../../packages/tta-lab {
    inherit ttalBinDir;
  };
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
in {
  environment.systemPackages = with pkgs; [
    # Shells and editors
    helix
    fish
    bash
    bubblewrap

    # Core tools
    openssh
    git
    git-filter-repo
    git-lfs
    git-sizer
    delta
    tmux
    pkgsUnstable.wezterm

    # Terminfo for SSH clients using modern terminal emulators.
    kitty.terminfo
    pkgsUnstable.wezterm.terminfo
    ghostty.terminfo

    gnumake

    # Search and data handling
    ripgrep
    fd
    bat
    tokei
    jq
    yq
    pkgsUnstable.defuddle
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
    ttaLab.ttalTmuxProjectPicker
    ttaLab.ttalWeztermProjects
    ttaLab.flicknote
    ttaLab.taskwarrior

    # Languages
    gcc
    pkgsUnstable.bun
    pkgsUnstable.go
    pkgsUnstable.golangci-lint
    python3
    llvmPackages.libclang

    # LSPs and dev tools
    pkgsUnstable.gopls
    pkgsUnstable.delve
    pkgsUnstable.typescript-language-server
    pkgsUnstable.vscode-langservers-extracted
    pkgsUnstable.biome

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
    pkgsUnstable.tanka
    jsonnet-bundler
    kubectx
    kubelogin
    kubernetes-helm
    helm-ls
    k9s
    pkgsUnstable.lazygit

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
    pkgsUnstable.lefthook
    shellcheck
  ];
}
