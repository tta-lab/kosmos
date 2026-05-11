_:

{
  # Phase 1: LAN proxy via Mac's clash verge.
  # Replace <mac-ip> with the actual Mac LAN IP at install time.
  networking.proxy.default = "http://<mac-ip>:7890";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal";
}
