_: {
  users.users.neil = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "podman"
    ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      # TODO: Add Neil's SSH public key(s).
    ];
  };
}
