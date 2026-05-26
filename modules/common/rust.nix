{
  pkgs,
  fenix,
  ...
}: {
  nixpkgs.overlays = [fenix.overlays.default];

  environment.systemPackages = [
    (pkgs.fenix.stable.withComponents [
      "cargo"
      "rustc"
      "rust-src"
      "rustfmt"
      "clippy"
    ])
    pkgs.rust-analyzer-nightly
  ];
}
