{
  config,
  pkgs,
  ...
}: let
  inherit (config.system) stateVersion;
  systemCaBundle = config.security.pki.caBundle;
  proxyEnvironment = config.kosmos.wsl.proxy.environment;
in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    users.neil = {
      lib,
      config,
      ...
    }: {
      imports = [
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

      home.sessionVariables =
        {
          NPM_CONFIG_PREFIX = "/home/neil/.local/share/npm-global";
          DSH_HOME = "/home/neil/.local/state/dsh";
          EDITOR = "hx";
          VISUAL = "hx";
          PI_RETRY_STALL_TIMEOUT_MS = "0";
          TACT_MODEL = "terra";
          NODE_EXTRA_CA_CERTS = systemCaBundle;
          AGENT_BROWSER_EXECUTABLE_PATH = "/run/current-system/sw/bin/chromium";
        }
        // proxyEnvironment;

      home.sessionPath = [
        "/home/neil/.local/bin"
        "/home/neil/go/bin"
        "/home/neil/.local/share/npm-global/bin"
      ];

      programs = {
        home-manager.enable = true;

        zsh = {
          enable = true;
          initContent = ''
            source ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
          '';
        };

        bash.enable = true;

        fish = {
          enable = true;
          shellInit = ''
            if test -r "$HOME/.config/env"
              source "$HOME/.config/env"
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
            naco = {
              description = "Run nanocodex with personal MCP servers";
              body = ''
                env \
                  NANOCODEX_MCP_DEFAULTS=false \
                  NANOCODEX_MCP_CODEX_CONFIG=true \
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
          ignores = [".nanocodex/" ".pi/" ".scratch/"];
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
