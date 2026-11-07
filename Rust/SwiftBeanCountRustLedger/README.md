# SwiftBeanCount Rust ledger bridge

This crate is an optional, stateless UniFFI wrapper around rustledger. It returns owned records and exact decimal text; it does not retain Swift objects or implement a second booking engine.

## Pinned components

- rustledger: `c01a3fbb4316c525db7a18275822ab5b0fceff31`
- Rust toolchain: `1.99.1` (`rust-toolchain.toml`)
- UniFFI runtime and command line generator: `0.29.5` (the generator uses the same locked UniFFI crate with its `cli` feature)

The wrapper's full loader enables rustledger's native plugins and validation. External plugin references produce engine diagnostics when no matching supported runtime is available. Encrypted-file loading is rejected explicitly; the bridge does not invoke GPG or another subprocess.

## Build and generate bindings

From the repository root, install the pinned Rust toolchain and set `PKG_CONFIG_PATH` to `.build/rustledger/pkgconfig` for opted-in SwiftPM builds. Then run:

```sh
Scripts/build-rustledger-artifacts.sh
Scripts/generate-rustledger-bindings.sh
```

Pass a Rust target triple to the build script for a cross-target static library. Binding generation always uses a host cdylib, since UniFFI must load the library while generating the shared Swift/C interface. Native archives and pkg-config files are written under `.build/rustledger/`; generated Swift and C declarations are checked in under `Sources/`.

The pinned upstream rustledger project declares GPL-3.0-only. This optional linked backend therefore needs a deliberate distribution and licensing decision before release; the pin does not change the license of the existing Swift package.
