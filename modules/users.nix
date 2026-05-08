{ config, pkgs, ... }:

{
  users.users.neil = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      # needed for key-based SSH auth (password auth via initialPassword is fallback)
      # TODO: Add Neil's SSH public key(s)
    ];
  };

  users.defaultUserShell = pkgs.fish;
}
