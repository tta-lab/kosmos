{
  pkgs,
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
