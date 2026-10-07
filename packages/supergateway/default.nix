{
  buildNpmPackage,
  fetchzip,
  lib,
}:
buildNpmPackage {
  pname = "supergateway";
  version = "4.2.0-rc.1";
  src = fetchzip {
    url = "https://github.com/supercorp-ai/supergateway/archive/60e35ced67eeead0ba025ec8cf1bccdb34763465.tar.gz";
    hash = "sha256-ZaHH/Nt8Mb8Spmz2/aj50FcZMGVQ8xAcWMKiZf9VBms=";
  };
  npmDepsHash = "sha256-ix1WNLU3QaTn0uAGXei4RDdpEhe6bx5OtDZhZBYVUcc=";
  npmFlags = ["--ignore-scripts"];
  env.HUSKY = "0";
  meta = {
    description = "MCP stdio to authenticated Streamable HTTP gateway";
    homepage = "https://github.com/supercorp-ai/supergateway";
    license = lib.licenses.mit;
    mainProgram = "supergateway";
  };
}
