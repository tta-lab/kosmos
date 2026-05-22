{
  bash,
  coreutils,
  fetchurl,
  fzf,
  gawk,
  gnused,
  jq,
  lib,
  stdenvNoCC,
  tmux,
  ttalBinDir ? null,
  writeShellApplication,
}: {
  flicknote = stdenvNoCC.mkDerivation {
    pname = "flicknote";
    version = "0.2.0";

    src = fetchurl {
      url = "https://github.com/GuionAI/flicknote-cli/releases/download/v0.2.0/flicknote-cli-x86_64-unknown-linux-musl.tar.xz";
      hash = "sha256-VHVEY42LUf4hY/S+kmX8GGwrBAYL0XFrlauVkthvprw=";
    };

    installPhase = ''
      runHook preInstall
      install -Dm755 flicknote $out/bin/flicknote
      install -Dm755 flicknote-sync $out/bin/flicknote-sync
      runHook postInstall
    '';
  };

  taskwarrior = stdenvNoCC.mkDerivation {
    pname = "taskwarrior-guion";
    version = "3.4.2-guion.15";

    src = fetchurl {
      url = "https://github.com/GuionAI/taskwarrior/releases/download/v3.4.2-guion.15/task-3.4.2-guion.15-x86_64-linux.tar.gz";
      hash = "sha256-ZAjDETPpx80E8ay/UCFFE/34Wy1bToZWhva0+Ck/i9g=";
    };
    # The archive has multiple top-level entries; keep unpacking at the archive root.
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 task $out/bin/task
      install -Dm644 completions/task.sh $out/share/bash-completion/completions/task
      install -Dm644 completions/_task $out/share/zsh/site-functions/_task
      install -Dm644 completions/task.fish $out/share/fish/vendor_completions.d/task.fish
      runHook postInstall
    '';
  };

  ttalTmuxProjectPicker = writeShellApplication {
    name = "ttal-tmux-project-picker";
    runtimeInputs = [
      bash
      coreutils
      fzf
      gawk
      gnused
      jq
      tmux
    ];
    text = ''
      ${lib.optionalString (ttalBinDir != null) ''
        export PATH=${lib.escapeShellArg ttalBinDir}:$PATH
      ''}
      exec ${bash}/bin/bash ${../../scripts/ttal-tmux-project-picker} "$@"
    '';
  };

  ttalWeztermProjects = writeShellApplication {
    name = "ttal-wezterm-projects";
    runtimeInputs = [
      bash
      jq
    ];
    text = ''
      ${lib.optionalString (ttalBinDir != null) ''
        export PATH=${lib.escapeShellArg ttalBinDir}:$PATH
      ''}
      exec ${bash}/bin/bash ${../../scripts/ttal-wezterm-projects} "$@"
    '';
  };
}
