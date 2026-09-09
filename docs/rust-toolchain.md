# Rust and WebAssembly on WSL

`modules/common/rust.nix` owns the system Rust toolchain. Fenix combines the
stable host components and `wasm32-unknown-unknown` standard library from the
same locked input, so normal `cargo` commands can build native and WebAssembly
targets without rustup or a command-specific `PATH`.

`packages/wasm-bindgen-cli` pins the CLI to 0.2.126, matching the current
Nanocodex workspace. The CLI and the project's `wasm-bindgen` crate must agree
on their binding schema; update this package deliberately when that requirement
changes. Cargo caches and project build artifacts remain outside Nix.

After applying the WSL configuration with `nh os switch . -H wsl`, verify:

```sh
command -v rustc cargo wasm-bindgen
rustc --version
rustc --print target-libdir --target wasm32-unknown-unknown
wasm-bindgen --version
```

Executables should resolve through the Nix system profile. Do not install a
parallel rustup toolchain to add a target missing from the Nix toolchain;
extend the Fenix combination instead. `rustup target add` modifies rustup's
own toolchains, not the compiler in `/run/current-system/sw/bin`.

For the Nanocodex consumer, run `corepack pnpm typecheck` from its checkout
using the normal environment. It builds the WASM binding before checking its
TypeScript consumers. No `RUSTUP_TOOLCHAIN`, absolute rustup compiler path, or
temporary `PATH` prefix should be needed.

Temporary installations from earlier troubleshooting are local cleanup, not
Nix activation logic. Remove only the identified redundant toolchain and
Cargo-installed CLI after the Nix replacement is active and verified; preserve
unrelated Cargo tools, caches, and pre-existing toolchains.
