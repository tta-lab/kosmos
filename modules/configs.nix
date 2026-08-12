{config, ...}: let
  inherit (config.system) stateVersion;
in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    users.neil = {lib, ...}: let
      proxyUrl = "http://127.0.0.1:7890";
      noProxy = "localhost,127.0.0.1,::1";
      flicknoteProxyEnvironment = [
        "HTTP_PROXY=${proxyUrl}"
        "HTTPS_PROXY=${proxyUrl}"
        "ALL_PROXY=${proxyUrl}"
        "NO_PROXY=${noProxy}"
        "http_proxy=${proxyUrl}"
        "https_proxy=${proxyUrl}"
        "all_proxy=${proxyUrl}"
        "no_proxy=${noProxy}"
      ];
    in {
      home = {
        username = "neil";
        homeDirectory = "/home/neil";
        inherit stateVersion;

        shellAliases = {
          vi = "command hx";
          ls = "command eza";
          lt = "command eza --tree";
          tree = "command eza --icons --classify --tree";
          lg = "command lazygit";
          catp = "command bat -P";
          cat = "command bat";
          yz = "command yazi";
          b = "command bat";
          k = "command kubectl";
          grep = "command rg";
          fn = "command flicknote";
          sc = "command spine-codex";
          pis = "command pi --model openai-codex/gpt-5.6-sol --thinking medium";
          pit = "command pi --model openai-codex/gpt-5.6-terra --thinking xhigh";
          pil = "command pi --model openai-codex/gpt-5.6-luna --thinking xhigh";
          pid = "command pi --model deepseek/deepseek-v4-flash --thinking high";
          ogv = "command og pr view";
          op = "command og push";
          ol = "command og pull";
        };

        activation.createCodeDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD mkdir -p \
            "$HOME/code/projects" \
            "$HOME/code/references" \
            "$HOME/.config/ttal" \
            "$HOME/.config/sops/age" \
            "$HOME/.kube"
        '';

        file = {
          ".taskrc".text = ''
            data.location=/home/neil/.task
            powersync.db_path=/home/neil/.local/share/flicknote/flicknote.db
            news.version=3.4.2
          '';
          ".codex/AGENTS.md".source = ../AGENTS.user.md;
          ".pi/agent/AGENTS.md".source = ../AGENTS.user.md;
        };
      };

      xdg = {
        enable = true;
        configFile = {
          "lenos/config.json".source = ../lenos/config.json;
          "temenos/config.toml".source = ../temenos/config.toml;
          "helix/config.toml".source = ../helix/config.toml;
          "helix/languages.toml".source = ../helix/languages.toml;
          "herdr/config.toml".source = ../herdr/config.toml;
          "herdr/open-project-space.fish" = {
            source = ../herdr/open-project-space.fish;
            executable = true;
          };
        };
      };

      home.sessionVariables = {
        NPM_CONFIG_PREFIX = "/home/neil/.local/share/npm-global";
        EDITOR = "hx";
        VISUAL = "hx";
      };

      home.sessionPath = [
        "/home/neil/.local/bin"
        "/home/neil/go/bin"
        "/home/neil/.local/share/npm-global/bin"
      ];

      systemd.user.services.flicknote-sync = {
        Unit = {
          Description = "FlickNote sync daemon";
          ConditionPathExists = "/home/neil/.local/bin/flicknote-sync";
        };
        Install.WantedBy = ["default.target"];
        Service = {
          ExecStart = "/home/neil/.local/bin/flicknote-sync";
          Restart = "on-failure";
          RestartSec = 5;
          Environment =
            [
              "RUST_LOG=flicknote_sync=info,powersync=debug"
            ]
            ++ flicknoteProxyEnvironment;
        };
      };

      programs = {
        home-manager.enable = true;

        bash.enable = true;

        fish = {
          enable = true;
          shellInit = ''
            if test -r "$HOME/.config/env"
              source "$HOME/.config/env"
            end
            set -gx HTTP_PROXY http://127.0.0.1:7890
            set -gx HTTPS_PROXY http://127.0.0.1:7890
            set -gx ALL_PROXY http://127.0.0.1:7890
            set -gx http_proxy http://127.0.0.1:7890
            set -gx https_proxy http://127.0.0.1:7890
            set -gx all_proxy http://127.0.0.1:7890
            set -gx NO_PROXY localhost,127.0.0.1,::1
            set -gx no_proxy localhost,127.0.0.1,::1
          '';
          functions = {
            p = ''
              set -l dir (command project jump $argv)
              or return 1
              test -n "$dir"
              or return 1
              cd -- "$dir"
            '';
            naco = {
              description = "Run nanocodex with personal MCP servers";
              body = ''
                env \
                  NANOCODEX_MCP_DEFAULTS=false \
                  NANOCODEX_BROWSER=none \
                  NANOCODEX_BROWSER_COOKIES=none \
                  NANOCODEX_WEB_SEARCH=false \
                  NANOCODEX_IMAGE_GENERATION=false \
                  NANOCODEX_SUBAGENTS=true \
                  OPENAI_REASONING_EFFORT=medium \
                  nanocodex \
                  $argv
              '';
            };
            nacot = {
              description = "Run nanocodex with Terra at xhigh reasoning effort";
              body = ''
                env \
                  NANOCODEX_MCP_DEFAULTS=false \
                  NANOCODEX_BROWSER=none \
                  NANOCODEX_BROWSER_COOKIES=none \
                  NANOCODEX_WEB_SEARCH=false \
                  NANOCODEX_IMAGE_GENERATION=false \
                  NANOCODEX_SUBAGENTS=true \
                  OPENAI_MODEL=terra \
                  OPENAI_REASONING_EFFORT=xhigh \
                  nanocodex \
                  $argv
              '';
            };
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
          ignores = [".nanocodex/"];
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
