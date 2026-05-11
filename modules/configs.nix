{ config, ... }:

let
  stateVersion = config.system.stateVersion;
in

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.neil = { lib, ... }: {
      home = {
        username = "neil";
        homeDirectory = "/home/neil";
        stateVersion = stateVersion;

        activation.createCodeDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p \
            "$HOME/code/projects" \
            "$HOME/code/references"
        '';
      };

      xdg = {
        enable = true;
        configFile = {
          "ttal/config.toml".source = ../ttal/config.toml;
          "ttal/humans.toml".source = ../ttal/humans.toml;
          "ttal/pipelines.toml".source = ../ttal/pipelines.toml;
          "ttal/projects.toml".source = ../ttal/projects.toml;
          "ttal/prompts.toml".source = ../ttal/prompts.toml;
          "ttal/roles.toml".source = ../ttal/roles.toml;
          "ttal/sandbox.toml".source = ../ttal/sandbox.toml;
          "einai/config.toml".source = ../einai/config.toml;
          "temenos/config.toml".source = ../temenos/config.toml;
          "helix/config.toml".source = ../helix/config.toml;
          "helix/languages.toml".source = ../helix/languages.toml;
        };
      };

      programs = {
        home-manager.enable = true;

        fish = {
          enable = true;
          shellInit = ''
            fish_add_path -g /home/neil/go/bin
          '';
          functions = {
            t = ''
              set -l dir (command ttal jump $argv)
              or return 1
              test -n "$dir"
              or return 1
              cd -- "$dir"
            '';
            vi = "command hx $argv";
            ls = "command eza $argv";
            lt = "command eza --tree $argv";
            tree = "command eza --icons --classify --tree $argv";
            lg = "command lazygit $argv";
            catp = "command bat -P $argv";
            cat = "command bat $argv";
            yz = "command yazi $argv";
            b = "command bat $argv";
            k = "command kubectl $argv";
            grep = "command rg $argv";
            fn = "command flicknote $argv";
          };
        };

        starship = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            add_newline = false;
            format = "$directory$git_branch$git_status$character";
            character = {
              success_symbol = "[>](bold green)";
              error_symbol = "[>](bold red)";
            };
            directory = {
              truncation_length = 3;
              truncate_to_repo = false;
            };
          };
        };

        git = {
          enable = true;
          userName = "neil";
          userEmail = "bn0010100@gmail.com";
          delta = {
            enable = true;
            options = {
              navigate = true;
              syntax-theme = "zenburn";
              dark = true;
            };
          };
          lfs.enable = true;
          extraConfig = {
            diff.colorMoved = "default";
            init.defaultBranch = "main";
            merge.conflictstyle = "diff3";
            pull.rebase = true;
            fetch.prune = true;
            tea.login = "forgejo";
          };
        };
      };
    };
  };
}
