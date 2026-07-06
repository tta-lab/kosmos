{
  fetchFromGitHub,
  lib,
  nodejs,
  pnpm,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "feishin-web";
  version = "0-unstable-2026-07-06";

  src = fetchFromGitHub {
    owner = "alsoGAMER";
    repo = "feishin";
    rev = "1961f14e063ddbe568c9ec6e815753d22d60f1e4";
    hash = "sha256-ptPHDuxSG0nKmemmR6kyIfxHVpR5ZYB/PEBB4OhkZLQ=";
  };

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src postPatch;
    fetcherVersion = 2;
    hash = "sha256-qLP9sqQMxUgfXLCubrj1Bd3JXxQtE9UHPI0tjjaimJU=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
  ];

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"resolutions": {' '"pnpm": {"overrides": {"xml2js": "0.5.0", "react-router": "7.14.0"}}, "resolutions": {'
    substituteInPlace src/renderer/index.html \
      --replace-fail 'src="settings.js"' 'src="settings.js?v=1961f14e-subsonic"'
    substituteInPlace src/renderer/router/app-outlet.tsx \
      --replace-fail "import { useAuthStore, useAuthStoreActions } from '/@/renderer/store';" "import { useAuthStore, useAuthStoreActions } from '/@/renderer/store';"$'\n'"import { toServerType } from '/@/shared/types/types';" \
      --replace-fail "url: state.currentServer.url," "url: state.currentServer.url,"$'\n'"                      type: state.currentServer.type," \
      --replace-fail "const persistedUrl = normalizeServerUrl(currentServer.url);"$'\n\n'"        return configuredUrl !== persistedUrl;" "const persistedUrl = normalizeServerUrl(currentServer.url);"$'\n'"        const configuredType = toServerType(window.SERVER_TYPE);"$'\n\n'"        return ("$'\n'"            configuredUrl !== persistedUrl ||"$'\n'"            (configuredType !== null && currentServer.type !== configuredType)"$'\n'"        );" \
      --replace-fail "updateServer(currentServer.id, {" "const configuredType = toServerType(window.SERVER_TYPE);"$'\n'"            updateServer(currentServer.id, {" \
      --replace-fail "url: normalizeServerUrl(window.SERVER_URL)," "url: normalizeServerUrl(window.SERVER_URL),"$'\n'"                ...(configuredType !== null ? { type: configuredType } : {}),"
  '';

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
