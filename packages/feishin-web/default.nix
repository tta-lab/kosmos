{
  fetchPnpmDeps,
  fetchFromGitHub,
  lib,
  nodejs,
  pnpm,
  pnpmConfigHook,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "feishin-web";
  version = "0-unstable-2026-07-06";

  src = fetchFromGitHub {
    owner = "tta-lab";
    repo = "feishin";
    rev = "f8dc0613dc75c9fea0745dc3e604822551e3c57d";
    hash = "sha256-FlppUurGs0M6XTWnkPAWHmXpSpH5Fb0Iay420AC8Tmo=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-H+LZ3t98pOnHy34OqVxQqMsMKybp7DIsPYt3EkJy8qY=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build:web
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/feishin-web"
    cp -r out/web/. "$out/share/feishin-web/"
    install -Dm644 settings.js.template "$out/share/feishin-web-settings/settings.js.template"
    runHook postInstall
  '';

  meta = {
    description = "Feishin web client with listen-together support";
    homepage = "https://github.com/alsoGAMER/feishin";
    license = lib.licenses.gpl3Only;
  };
})
