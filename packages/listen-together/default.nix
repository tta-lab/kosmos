{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule rec {
  pname = "listen-together";
  version = "1.0.6";

  src = fetchFromGitHub {
    owner = "alsoGAMER";
    repo = "listen-together";
    rev = "v${version}";
    hash = "sha256-l0vFLjCROkSOHfaMSuNRUKeQLBULXPmWk4nCmTKFs6Q=";
  };

  vendorHash = "sha256-0Qxw+MUYVgzgWB8vi3HBYtVXSq/btfh4ZfV/m1chNrA=";

  # The locked nixpkgs-unstable has Go 1.26.2 while upstream v1.0.6 declares
  # 1.26.4. The package builds on 1.26.2, so avoid a broad flake.lock update.
  postPatch = ''
    substituteInPlace go.mod \
      --replace-fail "go 1.26.4" "go 1.26.2"
  '';

  subPackages = ["cmd/listen-together"];

  meta = {
    description = "Synchronized playback coordinator for Navidrome and Subsonic-compatible clients";
    homepage = "https://github.com/alsoGAMER/listen-together";
    license = lib.licenses.mit;
    mainProgram = "listen-together";
  };
}
