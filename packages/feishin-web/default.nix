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
    # Keep this package on upstream alsoGAMER/feishin. These patches are
    # deployment glue for Kepos, not a maintained application fork.
    #
    # pnpm.fetchDeps runs postPatch too, so dependency-affecting package.json
    # edits must stay here rather than in a later build hook.
    substituteInPlace package.json \
      --replace-fail '"resolutions": {' '"pnpm": {"overrides": {"xml2js": "0.5.0", "react-router": "7.14.0"}}, "resolutions": {'
    # Force browsers to refetch settings.js after we changed SERVER_TYPE.
    substituteInPlace src/renderer/index.html \
      --replace-fail 'src="settings.js"' 'src="settings.js?v=1961f14e-subsonic"'
    # Feishin's server lock originally compared only SERVER_URL. Kepos moved
    # the same Navidrome endpoint from native Navidrome mode to Subsonic mode so
    # playlist coverArt works; persisted browser profiles must update type too.
    substituteInPlace src/renderer/router/app-outlet.tsx \
      --replace-fail "import { useAuthStore, useAuthStoreActions } from '/@/renderer/store';" "import { useAuthStore, useAuthStoreActions } from '/@/renderer/store';"$'\n'"import { toServerType } from '/@/shared/types/types';" \
      --replace-fail "url: state.currentServer.url," "url: state.currentServer.url,"$'\n'"                      type: state.currentServer.type," \
      --replace-fail "const persistedUrl = normalizeServerUrl(currentServer.url);"$'\n\n'"        return configuredUrl !== persistedUrl;" "const persistedUrl = normalizeServerUrl(currentServer.url);"$'\n'"        const configuredType = toServerType(window.SERVER_TYPE);"$'\n\n'"        return ("$'\n'"            configuredUrl !== persistedUrl ||"$'\n'"            (configuredType !== null && currentServer.type !== configuredType)"$'\n'"        );" \
      --replace-fail "updateServer(currentServer.id, {" "const configuredType = toServerType(window.SERVER_TYPE);"$'\n'"            updateServer(currentServer.id, {" \
      --replace-fail "url: normalizeServerUrl(window.SERVER_URL)," "url: normalizeServerUrl(window.SERVER_URL),"$'\n'"                ...(configuredType !== null ? { type: configuredType } : {}),"
    # New browser profiles should expose the player-bar room control without
    # asking users to discover Settings -> Playback first. Existing profiles may
    # keep their persisted sync settings.
    substituteInPlace src/renderer/store/sync.store.ts \
      --replace-fail "enabled: false," "enabled: (window as any).LISTEN_TOGETHER_ENABLED === true || (window as any).LISTEN_TOGETHER_ENABLED === 'true'," \
      --replace-fail $'sidecarUrl: \'\',' $'sidecarUrl: (window as any).LISTEN_TOGETHER_URL || \'\','
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
