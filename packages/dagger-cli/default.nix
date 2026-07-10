{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dagger-cli";
  version = "0.21.7";

  src = fetchurl {
    url = "https://dl.dagger.io/dagger/releases/${finalAttrs.version}/dagger_v${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-REMK/G+cOQ/EfE81KxXekwml6X69GuVjg5YX1t+OjMU=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm0755 dagger "$out/bin/dagger"

    runHook postInstall
  '';

  meta = {
    description = "Dagger CLI";
    homepage = "https://dagger.io";
    license = lib.licenses.asl20;
    mainProgram = "dagger";
    platforms = ["x86_64-linux"];
  };
})
