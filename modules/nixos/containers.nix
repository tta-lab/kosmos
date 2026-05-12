{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    podman
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };
}
