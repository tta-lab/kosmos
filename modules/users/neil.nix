_: {
  users.users.neil = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "podman"
    ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOI1HtKeFR8rm4DrSx7pyF5J/gYWmRzccwM7wOAi2yB1 neil@neilmac"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG1lFp9v39RA16BKELDv0n0FNVumRkNz3fhZ1TwXPEHH redock-android"
    ];
  };
}
