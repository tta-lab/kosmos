{ pkgs, ... }:

{
  programs = {
    fish = {
      enable = true;
      shellInit = ''
        function t
            set -l dir (command ttal jump $argv)
            or return 1
            test -n "$dir"
            or return 1
            cd -- "$dir"
        end

        function vi
            command hx $argv
        end

        function ls
            command eza $argv
        end

        function lt
            command eza --tree $argv
        end

        function tree
            command eza --icons --classify --tree $argv
        end

        function lg
            command lazygit $argv
        end

        function catp
            command bat -P $argv
        end

        function cat
            command bat $argv
        end

        function yz
            command yazi $argv
        end

        function b
            command bat $argv
        end

        function k
            command kubectl $argv
        end

        function grep
            command rg $argv
        end

        function fn
            command flicknote $argv
        end
      '';
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
