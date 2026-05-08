{ config, pkgs, ... }:

{
  environment.etc = {
    "ttal/config.toml".source = ../ttal/config.toml;
    "ttal/humans.toml".source = ../ttal/humans.toml;
    "ttal/pipelines.toml".source = ../ttal/pipelines.toml;
    "ttal/projects.toml".source = ../ttal/projects.toml;
    "ttal/prompts.toml".source = ../ttal/prompts.toml;
    "ttal/roles.toml".source = ../ttal/roles.toml;
    "ttal/sandbox.toml".source = ../ttal/sandbox.toml;
    "einai/config.toml".source = ../einai/config.toml;
    "temenos/config.toml".source = ../temenos/config.toml;
  };
}
