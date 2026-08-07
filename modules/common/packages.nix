{
  config,
  moonbitToolchain,
  pkgs,
  pkgsUnstable,
  ...
}: let
  ttalBinDir = pkgs.lib.attrByPath ["environment" "variables" "GOBIN"] null config;
  llvmMajorVersion = builtins.elemAt (builtins.splitVersion pkgs.llvmPackages.clang-unwrapped.version) 0;
  ttaLab = pkgs.callPackage ../../packages/tta-lab {
    inherit ttalBinDir;
  };
  enteBackup = pkgs.writeShellApplication {
    name = "kosmos-backup-ente";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      pkgs.kubectl
      pkgs.rsync
      pkgs.util-linux
    ];
    text = builtins.readFile ../../scripts/backup-ente;
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

    # Terminfo for SSH clients using modern terminal emulators.
    kitty.terminfo
    wezterm.terminfo
    ghostty.terminfo

    cmake
    gnumake

    # Archive tools
    unzip
    zip
    p7zip
    unar

    # Search and data handling
    ripgrep
    fd
    bat
    pkgsUnstable.ast-grep
    tokei
    jq
    yq
    pkgsUnstable.defuddle
    sqlite
    fzf
    direnv
    yazi

    # Media
    pkgsUnstable.ffmpeg
    poppler_utils
    typst
    source-han-serif-simplified-chinese

    # Network and HTTP
    pkgsUnstable.aria2
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
    openssl
    sops
    pkgsUnstable.just
    enteBackup
    ttaLab.ttalTmuxProjectPicker
    ttaLab.flicknote
    ttaLab.taskwarrior

    # Languages
    gcc
    pkgsUnstable.bun
    pkgsUnstable.pnpm
    pkgsUnstable.go
    pkgsUnstable.golangci-lint
    pkgsUnstable.gotestsum
    pkgsUnstable.cargo-deny
    pkgsUnstable.cargo-release
    moonbitToolchain
    python3
    pkgsUnstable.uv
    pkgsUnstable.ruff
    pkgsUnstable.basedpyright
    llvmPackages.libclang

    # LSPs and dev tools
    pkgsUnstable.gopls
    pkgsUnstable.delve
    pkgsUnstable.gofumpt
    pkgsUnstable.typescript-language-server
    pkgsUnstable.vscode-langservers-extracted
    pkgsUnstable.biome
    pkgsUnstable.shfmt
    pkgsUnstable.playwright

    # Recording
    pkgsUnstable.asciinema
    pkgsUnstable.asciinema-agg

    # Storage
    mdadm

    # System inspection
    btop
    eza
    duf
    dust
    gdu
    ncdu

    # Tunnels and ingress
    rathole
    cloudflared
    caddy

    # LLM tools
    pkgsUnstable.rtk

    # Cloud and Kubernetes
    gh
    hcloud
    kubectl
    pkgsUnstable.tanka
    jsonnet-bundler
    kubectx
    kubelogin
    kubernetes-helm
    kubeconform
    skopeo
    helm-ls
    k9s
    stern
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
    pkgsUnstable.trufflehog
  ];

  environment.sessionVariables = {
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.llvmPackages.clang-unwrapped.lib}/lib/clang/${llvmMajorVersion}/include";
  };
}
