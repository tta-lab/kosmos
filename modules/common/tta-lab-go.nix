let
  goPath = "/home/neil/go";
  goBin = "${goPath}/bin";
  goModCache = "${goPath}/pkg/mod";
  goCache = "/home/neil/.cache/go-build";
in {
  environment = {
    sessionVariables = {
      GOPATH = goPath;
      GOBIN = goBin;
      GOMODCACHE = goModCache;
      GOCACHE = goCache;
      GOTELEMETRY = "off";
    };
  };

  users.users.neil.linger = true;
}
