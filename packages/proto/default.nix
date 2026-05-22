{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "proto";
  version = "0.57.2";

  src = fetchurl {
    url = "https://github.com/moonrepo/proto/releases/download/v${finalAttrs.version}/proto_cli-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-xvbX9C+qI1ZDOGq23pQb/tZUWlVqvJ9H1C95z93EJgc=";
  };

  sourceRoot = "proto_cli-x86_64-unknown-linux-gnu";

  installPhase = ''
    runHook preInstall

    install -Dm755 proto "$out/bin/proto"
    install -Dm755 proto-shim "$out/bin/proto-shim"
    install -Dm644 README.md "$out/share/doc/proto/README.md"
    install -Dm644 CHANGELOG.md "$out/share/doc/proto/CHANGELOG.md"
    install -Dm644 LICENSE "$out/share/licenses/proto/LICENSE"

    runHook postInstall
  '';

  meta = {
    description = "Pluggable multi-language version manager";
    homepage = "https://github.com/moonrepo/proto";
    license = lib.licenses.mit;
    mainProgram = "proto";
    platforms = ["x86_64-linux"];
  };
})
