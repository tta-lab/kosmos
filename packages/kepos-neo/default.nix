{
  lib,
  buildNpmPackage,
  esbuild,
  jq,
  makeWrapper,
  nodejs_22,
  runCommand,
  src,
}: let
  patchedSrc =
    runCommand "kepos-neo-source" {
      nativeBuildInputs = [jq];
    } ''
      cp -R ${src} "$out"
      chmod -R u+w "$out"
      jq --slurpfile metadata ${./runtime-lock-integrity.json} '
        .packages |= with_entries(
          if $metadata[0][.key] then
            .value += {
              resolved: (
                (.key | sub("^node_modules/"; "")) as $name
                | ($name | split("/") | last) as $basename
                | "https://registry.npmjs.org/\($name)/-/\($basename)-\(.value.version).tgz"
              ),
              integrity: $metadata[0][.key]
            }
          else . end
        )
      ' "$out/package-lock.json" >package-lock.json
      mv package-lock.json "$out/package-lock.json"
    '';
in
  buildNpmPackage {
    pname = "kepos-neo";
    version = "0.0.0-b265df5";

    src = patchedSrc;
    npmDepsHash = "sha256-Ja0eih7rQKstl64wUwvNTgN59IPJq2pD+6ZJkwXgIwY=";
    nodejs = nodejs_22;
    dontNpmBuild = true;
    npmFlags = ["--omit=dev"];

    nativeBuildInputs = [esbuild makeWrapper];

    buildPhase = ''
      runHook preBuild

      while IFS= read -r source_file; do
        output_file="dist/''${source_file#src/}"
        output_file="''${output_file%.ts}.js"
        mkdir -p "$(dirname "$output_file")"
        esbuild "$source_file" \
          --format=esm \
          --platform=node \
          --target=node22 \
          --outfile="$output_file"
      done < <(find src -type f -name '*.ts' ! -path 'src/android/*' | sort)

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/kepos-neo" "$out/bin"
      cp -R dist home package.json node_modules "$out/lib/kepos-neo/"
      unlink "$out/lib/kepos-neo/node_modules/@tta-lab/bare-host-protocol"
      unlink "$out/lib/kepos-neo/node_modules/@tta-lab/kepos-android-worklet"
      makeWrapper ${nodejs_22}/bin/node "$out/bin/kepos" \
        --add-flags "$out/lib/kepos-neo/dist/cli/main.js"

      runHook postInstall
    '';

    meta = {
      description = "Private peer-to-peer service publisher and subscriber";
      homepage = "https://github.com/tta-lab/kepos-neo";
      license = lib.licenses.asl20;
      mainProgram = "kepos";
      platforms = lib.platforms.linux;
    };
  }
