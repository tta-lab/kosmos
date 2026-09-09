{
  pkgs,
  pkgsUnstable,
  fenix,
  ...
}: {
  nixpkgs.overlays = [fenix.overlays.default];

  nix.settings = {
    extra-substituters = ["https://fenix.cachix.org"];
    extra-trusted-public-keys = [
      "fenix.cachix.org-1:ecJhr+RdYEdcVgUkjruiYhjbBloIEGov7bos90cZi0Q="
    ];
  };

  environment.systemPackages = [
    (pkgs.fenix.combine [
      (pkgs.fenix.stable.withComponents [
        "cargo"
        "rustc"
        "rust-src"
        "rustfmt"
        "clippy"
      ])
      pkgs.fenix.targets.wasm32-unknown-unknown.stable.rust-std
    ])
    (pkgsUnstable.callPackage ../../packages/wasm-bindgen-cli {})
    pkgs.rust-analyzer-nightly
  ];
}
