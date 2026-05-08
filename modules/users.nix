{ config, pkgs, ... }:

{
  users.users.neil = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      # TODO: Add Neil's SSH public key(s)
    ];
  };

  users.defaultUserShell = pkgs.fish;
}
