{
  fetchCrate,
  rustPlatform,
  wasm-bindgen-cli,
}: let
  version = "0.2.126";
  src = fetchCrate {
    pname = "wasm-bindgen-cli";
    inherit version;
    unpack = false;
    hash = "sha256-ji6/bu+Hw05mI0fx3d++pUEwS7cpRxHtLCrNh0bMW1A=";
  };
in
  wasm-bindgen-cli.overrideAttrs {
    inherit version src;
    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-VucqkXbCi4qtQzY/HrXiDnbSURsagPsdNVMn1Tw3UiY=";
    };
  }
