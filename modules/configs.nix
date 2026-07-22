{
  config,
  pkgs,
  ...
}: let
  inherit (config.system) stateVersion;
  ttaLab = pkgs.callPackage ../packages/tta-lab {};
in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    users.neil = {lib, ...}: {
      home = {
        username = "neil";
        homeDirectory = "/home/neil";
        inherit stateVersion;

        activation.createCodeDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD mkdir -p \
            "$HOME/code/projects" \
            "$HOME/code/references" \
            "$HOME/.config/ttal" \
            "$HOME/.config/sops/age" \
            "$HOME/.ttal" \
            "$HOME/.kube"
        '';

        file = {
          ".taskrc".text = ''
            data.location=/home/neil/.task
            powersync.db_path=/home/neil/.local/share/flicknote/flicknote.db
            news.version=3.4.2
          '';
          ".claude/CLAUDE.md".source = ../CLAUDE.user.md;
          ".codex/AGENTS.md".source = ../CLAUDE.user.md;
        };
      };

      xdg = {
        enable = true;
        configFile = {
          "ttal/config.toml".source = ../ttal/config.toml;
          "ttal/humans.toml".source = ../ttal/humans.toml;
          "ttal/pipelines.toml".source = ../ttal/pipelines.toml;
          "ttal/orgs.toml".source = ../ttal/orgs.toml;
          "ttal/projects.toml".source = ../ttal/projects.toml;
          "ttal/prompts.toml".source = ../ttal/prompts.toml;
          "ttal/roles.toml".source = ../ttal/roles.toml;
          "ttal/sandbox.toml".source = ../ttal/sandbox.toml;
          "lenos/config.json".source = ../lenos/config.json;
          "einai/config.toml".source = ../einai/config.toml;
          "temenos/config.toml".source = ../temenos/config.toml;
          "helix/config.toml".source = ../helix/config.toml;
          "helix/languages.toml".source = ../helix/languages.toml;
        };
      };

      home.sessionVariables = {
        NPM_CONFIG_PREFIX = "/home/neil/.local/share/npm-global";
        EDITOR = "hx";
        VISUAL = "hx";
      };

      systemd.user.services.flicknote-sync = {
        Unit.Description = "FlickNote sync daemon";
        Install.WantedBy = ["default.target"];
        Service = {
          ExecStart = "${ttaLab.flicknote}/bin/flicknote-sync";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [
            "RUST_LOG=flicknote_sync=info,powersync=debug"
          ];
        };
      };

      programs = {
        home-manager.enable = true;

        fish = {
          enable = true;
          shellInit = ''
            fish_add_path -g /home/neil/go/bin
            fish_add_path -g /home/neil/.local/share/npm-global/bin
            if test -r "$HOME/.config/env"
              source "$HOME/.config/env"
            end
            if test "${toString config.kosmos.wsl.windowsProxy.enable}" = "true"
              if command -q kosmos-wsl-proxy-env
                kosmos-wsl-proxy-env fish | source
              end
            else
              set -gx HTTP_PROXY ${config.kosmos.wsl.mihomoProxyUrl}
              set -gx HTTPS_PROXY ${config.kosmos.wsl.mihomoProxyUrl}
              set -gx ALL_PROXY ${config.kosmos.wsl.mihomoProxyUrl}
              set -gx NO_PROXY localhost,127.0.0.1,::1
            end
          '';
          functions = {
            p = ''
              set -l dir (command project jump $argv)
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
            ogv = "command og pr view $argv";
            ogp = "command og git push $argv";
            ogl = "command og git pull $argv";
          };
        };

        starship = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            add_newline = false;
            format = "$directory$git_branch$git_status\n$character";
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
            credential.interactive = false;
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
