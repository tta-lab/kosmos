{
  bash,
  coreutils,
  fzf,
  gawk,
  gnused,
  jq,
  lib,
  tmux,
  ttalBinDir ? null,
  writeShellApplication,
}: {
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
}
