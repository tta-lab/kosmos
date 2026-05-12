{
  config,
  pkgs,
  ...
}: let
  ttalBinDir = pkgs.lib.attrByPath ["environment" "variables" "GOBIN"] null config;
  ttaLab = pkgs.callPackage ../../packages/tta-lab {
    inherit ttalBinDir;
  };
in {
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
      extraConfig =
        builtins.replaceStrings
        ["@ttalTmuxProjectPicker@"]
        ["${ttaLab.ttalTmuxProjectPicker}/bin/ttal-tmux-project-picker"]
        (builtins.readFile ../../tmux/.tmux.conf);
    };
  };

  users.defaultUserShell = pkgs.fish;
}
