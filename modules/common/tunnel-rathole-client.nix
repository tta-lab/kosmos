{ ... }:

{
  services.rathole = {
    enable = false;
    role = "client";
    credentialsFile = "/var/lib/secrets/rathole/client.toml";

    settings = {
      client = {
        remote_addr = "vps.example.com:2333";

        services.ssh = {
          local_addr = "127.0.0.1:22";
        };
      };
    };
  };
}
