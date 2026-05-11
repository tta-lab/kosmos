_:

{
  systemd.tmpfiles.rules = [
    "d /home/neil/code 0755 neil users - -"
    "d /home/neil/code/projects 0755 neil users - -"
    "d /home/neil/code/references 0755 neil users - -"

    "d /home/neil/.config 0700 neil users - -"
    "d /home/neil/.config/ttal 0755 neil users - -"
    "d /home/neil/.config/einai 0755 neil users - -"
    "d /home/neil/.config/temenos 0755 neil users - -"
    "d /home/neil/.config/helix 0755 neil users - -"

    "L+ /home/neil/.config/ttal/config.toml - - - - ${../ttal/config.toml}"
    "L+ /home/neil/.config/ttal/humans.toml - - - - ${../ttal/humans.toml}"
    "L+ /home/neil/.config/ttal/pipelines.toml - - - - ${../ttal/pipelines.toml}"
    "L+ /home/neil/.config/ttal/projects.toml - - - - ${../ttal/projects.toml}"
    "L+ /home/neil/.config/ttal/prompts.toml - - - - ${../ttal/prompts.toml}"
    "L+ /home/neil/.config/ttal/roles.toml - - - - ${../ttal/roles.toml}"
    "L+ /home/neil/.config/ttal/sandbox.toml - - - - ${../ttal/sandbox.toml}"
    "L+ /home/neil/.config/einai/config.toml - - - - ${../einai/config.toml}"
    "L+ /home/neil/.config/temenos/config.toml - - - - ${../temenos/config.toml}"
    "L+ /home/neil/.config/helix/config.toml - - - - ${../helix/config.toml}"
    "L+ /home/neil/.config/helix/languages.toml - - - - ${../helix/languages.toml}"
  ];
}
