# SwiftBeanCount Rust ledger bridge

This crate is an optional, stateless UniFFI wrapper around rustledger. It returns owned records and exact decimal text; it does not retain Swift objects or implement a second booking engine.

## Pinned components

- rustledger: `c01a3fbb4316c525db7a18275822ab5b0fceff31`
- Rust toolchain: `1.99.1` (`rust-toolchain.toml`)
- UniFFI runtime and command line generator: `0.29.5` (the generator uses the same locked UniFFI crate with its `cli` feature)

The wrapper's full loader enables rustledger's native plugins and validation. External plugin references produce engine diagnostics when no matching supported runtime is available. Encrypted-file loading is rejected explicitly; the bridge does not invoke GPG or another subprocess.

## Build in Xcode

Install Xcode, Python 3, and the pinned Rust toolchain first. From the repository root, run:

```sh
python3 Scripts/prepare-rustledger-xcode.py
```

This compiles Rust locally and creates an XCFramework plus matching UniFFI bindings in
`Artifacts/RustLedger/current`. The default includes macOS and iOS Simulator for your Mac's
architecture, plus arm64 iOS devices. Install missing destination libraries with the
`rustup target add --toolchain 1.99.1 ...` command printed by the script. Use `--universal`
to also include Intel Mac and simulator slices. To prepare only macOS:

```sh
python3 Scripts/prepare-rustledger-xcode.py --platform macos
```

Then open `SwiftBeanCountApp.xcodeproj` normally, select the project under **PROJECT**,
open **Package Dependencies**, and enable **RustLedger** for the local SwiftBeanCount
package. Select **SwiftBeanCountApp** and your destination, then use Build/Run as usual.
If the project was open during initial preparation, close and reopen it to reload the
package. No special Xcode launch command, environment variables, or `pkg-config` is needed.

Rerun preparation after changing Rust sources, dependencies, toolchain, or build scripts,
or to add destinations. The bindings plugin detects stale or damaged artifacts and reports
the preparation command. Artifacts are ignored by Git and survive Xcode's Clean Build Folder.
Preparation reuses the existing native build cache; do not run it concurrently with an Xcode
build. Cargo compilation is deliberately separate: Xcode must resolve a local binary target
before running build phases, and build-tool plugins cannot reliably supply native linker
inputs or fetch Cargo dependencies.

Disabling RustLedger keeps the Swift backend usable on an unprepared checkout without Rust.
The existing generated app-project script remains useful for CI; it is not needed locally.

## Source-based command-line builds

For Linux or Rust development, keep using the source-build wrapper (requires `pkg-config`):

```sh
python3 Scripts/with-rustledger.py -- swift test --traits RustLedger
```

For an iOS simulator on Apple silicon, pass `--target aarch64-apple-ios-sim` before `--`
and provide the corresponding `xcodebuild` command. The wrapper builds the pinned Rust
sources, generates UniFFI declarations from the static archive, and sets the binding and
linker paths for its child process. It takes precedence over prepared Xcode artifacts.
Native builds and binding generation are cached under `.build/rustledger/`.

The pinned upstream rustledger project declares GPL-3.0-only. This optional linked backend therefore needs a deliberate distribution and licensing decision before release; the pin does not change the license of the existing Swift package.
