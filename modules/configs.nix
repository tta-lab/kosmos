{
  config,
  pkgs,
  nix-openclaw,
  ...
}: let
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
      imports = [
        nix-openclaw.homeManagerModules.openclaw
      ];

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
          pit = "command pi --model openai-codex/gpt-5.6-terra --thinking max";
          pil = "command pi --model openai-codex/gpt-5.6-luna --thinking max";
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
          ".pi/sync-codex-auth.ts" = {
            source = ../scripts/sync-codex-auth.ts;
            executable = true;
          };
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

      # nix-openclaw generates openclaw-gateway without an Install section;
      # merge WantedBy in so the gateway starts with the user session.
      # OPENCLAW_CONFIG_PATH is overridden to the jsonnet-generated file
      # (openclaw/openclaw.jsonnet, deployed via 'just openclaw-deploy');
      # the module's rendered store config is dead. HM merges Environment
      # lists, so this value wins over the module's (later in the list).
      systemd.user.services.openclaw-gateway = {
        Install.WantedBy = ["default.target"];
        Service.Environment = ["OPENCLAW_CONFIG_PATH=/home/neil/.config/openclaw/openclaw.json"];
      };

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

        openclaw = {
          enable = true;
          package = nix-openclaw.packages.${pkgs.system}.openclaw;

          # Yuki (whale girl) workspace is edited directly on this machine
          # (not the kosmos repo); make it the OpenClaw workspace so edits
          # take effect on the next session without a switch.
          workspaceDir = "/home/neil/openclaw-workspace";

          # openclaw.json content is generated from openclaw/openclaw.jsonnet
          # (deploy: just openclaw-deploy — jsonnet render, write the file,
          # restart the gateway). The module still provides the systemd unit,
          # wrapper, and env injection; its rendered config file is dead —
          # OPENCLAW_CONFIG_PATH is overridden below to point at the jsonnet
          # output instead.

          # Values that point to existing files are read at runtime by the
          # gateway wrapper, so secrets never land in the Nix store.
          # Values that point to existing files are read at runtime by the
          # gateway wrapper, so secrets never land in the Nix store. Telegram
          # token goes via env because OpenClaw rejects symlinked tokenFiles
          # (agenix targets are symlinks).
          environment = {
            OPENCLAW_GATEWAY_TOKEN = "/home/neil/.config/openclaw/gateway-token";
            DEEPSEEK_API_KEY = "/home/neil/.config/openclaw/deepseek-key";
            TELEGRAM_BOT_TOKEN = "/home/neil/.config/openclaw/telegram-token";
            # systemd user services have a minimal default PATH; the MCP
            # commands (flicknote/web/og/project/src) live in ~/.local/bin
            # and ~/go/bin, so make them reachable.
            PATH = "/home/neil/.local/bin:/home/neil/go/bin:/home/neil/.local/share/npm-global/bin:/run/current-system/sw/bin:$PATH";
            # Node fetch honors the env proxy; local k3s services live under
            # *.localhost (/etc/hosts) and must bypass it — mihomo can't
            # resolve those names, and Caddy routes by Host header so
            # 127.0.0.1 is not a substitute.
            NO_PROXY = "localhost,127.0.0.1,::1,*.localhost";
            no_proxy = "localhost,127.0.0.1,::1,*.localhost";
          };
        };

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
          ignores = [".nanocodex/" ".pi/"];
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
