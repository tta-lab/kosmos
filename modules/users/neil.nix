_:

{
  users.users.neil = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      # TODO: Add Neil's SSH public key(s).
    ];
  };
}
