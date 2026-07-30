{config, ...}: {
  services.openvpn.servers.client = {
    autoStart = true;
    config = ''
      config ${config.age.secrets.openvpn-config.path}
      auth-user-pass ${config.age.secrets.openvpn-auth.path}
    '';
  };

  systemd.services.openvpn-client.restartTriggers = [
    config.age.secrets.openvpn-config.file
    config.age.secrets.openvpn-auth.file
  ];
}
