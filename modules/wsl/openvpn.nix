{config, ...}: {
  services.openvpn.servers.client = {
    autoStart = false;
    config = ''
      config ${config.age.secrets.openvpn-config.path}
      auth-user-pass ${config.age.secrets.openvpn-auth.path}
      data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-128-CBC
    '';
  };

  systemd.services.openvpn-client = {
    enable = false;
    restartTriggers = [
      config.age.secrets.openvpn-config.file
      config.age.secrets.openvpn-auth.file
    ];
  };
}
