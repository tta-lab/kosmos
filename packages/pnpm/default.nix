{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pnpm";
  version = "12.3.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/pnpm/-/pnpm-${finalAttrs.version}.tgz";
    hash = "sha256-CKPS1Tmzd6a36iRpthJnIlXKccMKYmmFMFgsudNcJo8=";
  };
  nativeBinary = fetchurl {
    url = "https://registry.npmjs.org/@pnpm/exe.linux-x64/-/exe.linux-x64-${finalAttrs.version}.tgz";
    hash = "sha256-mxyV/EE2AMp1pR6+gzLXAZ3DVo/UGH9aXy30oVbvtlw=";
  };

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/pnpm" "$out/bin"
    cp -r . "$out/libexec/pnpm/"
    tar -xzf "$nativeBinary" --strip-components=1 -C "$out/libexec/pnpm" package/pnpm
    chmod +x "$out/libexec/pnpm/pnpm"
    for command in pnpm pn pnpx pnx; do
      ln -s "$out/libexec/pnpm/$command" "$out/bin/$command"
    done

    runHook postInstall
  '';

  meta = {
    description = "Fast, disk space efficient package manager";
    homepage = "https://pnpm.io";
    license = lib.licenses.mit;
    mainProgram = "pnpm";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
