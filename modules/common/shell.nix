{pkgs, ...}: {
  programs = {
    fish = {
      enable = true;
    };

    mosh.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    tmux = {
      enable = true;
      terminal = "tmux-256color";
      extraConfig = builtins.readFile ../../tmux/.tmux.conf;
    };
  };

  users.defaultUserShell = pkgs.fish;
}
