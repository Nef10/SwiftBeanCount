#!/usr/bin/env python3
"""Prepare cached RustLedger artifacts, then run a Swift or Xcode command.

Example: Scripts/with-rustledger.py -- swift test --traits RustLedger
Cross-compilation requires --target, e.g. aarch64-apple-ios-sim.
"""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
CRATE = ROOT / "Rust/SwiftBeanCountRustLedger"
LIBRARY = "swiftbeancount_rust_ledger"
REVISION = "c01a3fbb4316c525db7a18275822ab5b0fceff31"
OUTPUTS = (f"lib{LIBRARY}.a", "bindings.swift", f"{LIBRARY}_generated.h", "swiftbeancount-rustledger.pc")


def capture(command: list[str], env: dict[str, str] | None = None) -> str:
    return subprocess.check_output(command, cwd=CRATE, env=env, text=True).strip()


def run(command: list[str], env: dict[str, str]) -> str:
    print("[RustLedger] " + shlex.join(command), file=sys.stderr, flush=True)
    process = subprocess.Popen(command, cwd=CRATE, env=env, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = []
    assert process.stdout is not None
    for line in process.stdout:
        print(line, end="", file=sys.stderr, flush=True)
        lines.append(line)
    if process.wait():
        raise subprocess.CalledProcessError(process.returncode, command)
    return "".join(lines)


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def source_inputs() -> dict[str, str]:
    """Fingerprint the wrapper and local Cargo path dependencies, excluding build output."""
    metadata = json.loads(capture(["cargo", "metadata", "--locked", "--format-version", "1"]))
    directories = {CRATE}
    for package in metadata["packages"]:
        if package["source"] is None:
            directories.add(Path(package["manifest_path"]).parent)
    inputs = {str(Path(__file__).resolve()): digest(Path(__file__))}
    for directory in sorted(directories):
        for parent, children, files in os.walk(directory):
            children[:] = sorted(name for name in children if name not in ("target", ".git", ".build"))
            for name in sorted(files):
                path = Path(parent) / name
                inputs[str(path)] = digest(path)
    # Cargo can pick up configuration from each ancestor and the user's Cargo home.
    cargo_home = Path(os.environ.get("CARGO_HOME", str(Path.home() / ".cargo")))
    for parent in (CRATE, *CRATE.parents, cargo_home):
        config_dir = parent if parent == cargo_home else parent / ".cargo"
        for name in ("config", "config.toml"):
            path = config_dir / name
            if path.is_file():
                inputs[str(path)] = digest(path)
    return inputs


def configuration(args: argparse.Namespace) -> tuple[dict, dict[str, str]]:
    env = os.environ.copy()
    rust = capture(["rustc", "-vV"])
    version = re.search(r'^channel\s*=\s*"([^"]+)"', (CRATE / "rust-toolchain.toml").read_text(), re.M)[1]
    if not rust.startswith(f"rustc {version} "):
        raise ValueError(f"Expected rustc {version}; install the pinned toolchain. Found {rust.splitlines()[0]}")
    if f"?rev={REVISION}#{REVISION}" not in (CRATE / "Cargo.lock").read_text():
        raise ValueError("Cargo.lock does not contain the pinned rustledger revision")
    host = re.search(r"^host: (.+)$", rust, re.M)[1]
    target = args.target or host
    sdk = None
    if "-apple-ios" in target:
        sdk = "iphonesimulator" if target.endswith("-sim") or target.startswith("x86_64-") else "iphoneos"
        env["IPHONEOS_DEPLOYMENT_TARGET"] = args.deployment_target or env.get("IPHONEOS_DEPLOYMENT_TARGET", "16.0")
    elif target.endswith("-apple-darwin"):
        sdk = "macosx"
        env["MACOSX_DEPLOYMENT_TARGET"] = args.deployment_target or env.get("MACOSX_DEPLOYMENT_TARGET", "13.0")
    elif args.deployment_target:
        raise ValueError("--deployment-target applies only to Apple destinations")
    sdk_identity = None
    if sdk:
        env["SDKROOT"] = capture(["xcrun", "--sdk", sdk, "--show-sdk-path"])
        sdk_identity = {key: capture(["xcrun", "--sdk", sdk, f"--show-sdk-{key}"])
                        for key in ("path", "version", "build-version")}
    # Force the selected target even if a surrounding Cargo configuration chooses another.
    relevant = {key: hashlib.sha256(value.encode()).hexdigest() for key, value in env.items()
                if key.startswith(("CARGO_", "RUST", "CC", "CFLAGS", "CXX", "AR_"))
                or key in ("AR", "SDKROOT", "MACOSX_DEPLOYMENT_TARGET", "IPHONEOS_DEPLOYMENT_TARGET", "PATH")}
    config = {"rust": rust, "cargo": capture(["cargo", "-V"]), "host": host, "target": target,
              "profile": args.profile, "sdk": sdk_identity, "environment": relevant,
              "inputs": source_inputs()}
    return config, env


def valid_entry(entry: Path, key: str) -> bool:
    try:
        manifest = json.loads((entry / "manifest.json").read_text())
        return (manifest["key"] == key and set(manifest["outputs"]) == set(OUTPUTS)
                and all(digest(entry / name) == checksum for name, checksum in manifest["outputs"].items()))
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False


@contextlib.contextmanager
def locked(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield
        # flock is released by the OS on normal exit, interruption, or process death.


def prepare(args: argparse.Namespace) -> tuple[Path, dict[str, str]]:
    config, env = configuration(args)
    # Published .pc paths are absolute; a relocated cache must publish a fresh entry.
    config["publication_root"] = str(args.cache_dir.resolve())
    key = hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()
    cache = args.cache_dir.resolve()
    entry = cache / "artifacts" / key
    cargo_target = Path(env.get("CARGO_TARGET_DIR", str(cache / "cargo"))).resolve()
    env["CARGO_TARGET_DIR"] = str(cargo_target)
    # Protect publication and copying out of Cargo's mutable target directory too.
    with locked(cargo_target / ".swiftbeancount-build.lock"):
        if valid_entry(entry, key):
            print(f"[RustLedger] cache hit: {config['target']} ({args.profile})", file=sys.stderr)
            return entry, env
        print(f"[RustLedger] cache miss: {config['target']} ({args.profile})", file=sys.stderr)
        entry.parent.mkdir(parents=True, exist_ok=True)
        # A killed writer may leave staging directories; none are ever cache hits.
        for stale in entry.parent.glob(f".{key}-*"):
            shutil.rmtree(stale)
        with tempfile.TemporaryDirectory(prefix=f".{key}-", dir=entry.parent) as temporary:
            stage = Path(temporary)
            output = run(["cargo", "rustc", "--lib", "--locked", "--profile", args.profile,
                          "--target", config["target"], "--", "--print=native-static-libs"], env)
            libraries = re.findall(r"native-static-libs:\s*(.+)", output)
            if not libraries:
                raise ValueError("Rust did not report its native static link libraries")
            profile_dir = "debug" if args.profile == "dev" else args.profile
            archive = cargo_target / config["target"] / profile_dir / f"lib{LIBRARY}.a"
            shutil.copy2(archive, stage / archive.name)
            host_env = env.copy()
            if config["host"].endswith("-apple-darwin"):
                host_env["SDKROOT"] = capture(["xcrun", "--sdk", "macosx", "--show-sdk-path"])
            run(["cargo", "build", "--locked", "--bin", "uniffi-bindgen", "--features", "uniffi-cli",
                 "--target", config["host"]], host_env)
            generator = cargo_target / config["host"] / "debug/uniffi-bindgen"
            generated = stage / "generated"
            generated.mkdir()
            # UniFFI 0.29.5 extracts metadata from archives, including cross-compiled ones.
            run([str(generator), "generate", "--library", str(stage / archive.name),
                 "--language", "swift", "--out-dir", str(generated), "--no-format"], host_env)
            shutil.copy2(generated / f"{LIBRARY}.swift", stage / "bindings.swift")
            shutil.copy2(generated / f"{LIBRARY}FFI.h", stage / f"{LIBRARY}_generated.h")
            shutil.rmtree(generated)
            if source_inputs() != config["inputs"]:
                raise ValueError("Rust build inputs changed during preparation; rerun the command")
            # SwiftPM's .pc parser supports double quotes, but not shell single quotes.
            quoted_entry = json.dumps(str(entry), ensure_ascii=False)
            (stage / "swiftbeancount-rustledger.pc").write_text(
                f"Name: swiftbeancount-rustledger\nDescription: Source-built RustLedger bridge\nVersion: 0.1.0\n"
                f"Libs: -L{quoted_entry} -l{LIBRARY} {libraries[-1]}\n"
                f"Cflags: -I{quoted_entry}\n")
            (stage / "manifest.json").write_text(json.dumps({
                "key": key, "configuration": config,
                "outputs": {name: digest(stage / name) for name in OUTPUTS},
            }, indent=2) + "\n")
            if entry.exists():
                shutil.rmtree(entry)
            os.replace(stage, entry)
    return entry, env


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", help="Rust destination triple; defaults to the host")
    parser.add_argument("--profile", choices=("dev", "release"), default="release")
    parser.add_argument("--deployment-target", help="Apple minimum OS version (defaults: macOS 13, iOS 16)")
    parser.add_argument("--cache-dir", type=Path, default=ROOT / ".build/rustledger")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command after --, e.g. swift test --traits RustLedger")
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("Supply a command after --")
    if not args.target and any("iOS" in arg or "iphone" in arg.lower() or arg == "--triple" for arg in command):
        parser.error("Cross-compilation requires an explicit --target Rust destination triple")
    destination = " ".join(command).lower()
    if args.target and ("platform=ios" in destination or "iphone" in destination):
        simulator = "ios simulator" in destination or "iphonesimulator" in destination
        target_simulator = args.target.endswith("-sim") or args.target == "x86_64-apple-ios"
        if "-apple-ios" not in args.target or simulator != target_simulator:
            parser.error("--target does not match the requested iOS device/simulator destination")
    if not shutil.which("pkg-config"):
        parser.error("Install pkg-config before building RustParser")
    try:
        entry, env = prepare(args)
        env["PKG_CONFIG_PATH"] = str(entry) + (os.pathsep + env["PKG_CONFIG_PATH"] if env.get("PKG_CONFIG_PATH") else "")
        env["SWIFTBEANCOUNT_RUST_BINDINGS"] = str(entry / "bindings.swift")
        # Preserve the caller's Swift/Xcode SDK selection; SDKROOT above was for Cargo.
        if "SDKROOT" in os.environ:
            env["SDKROOT"] = os.environ["SDKROOT"]
        else:
            env.pop("SDKROOT", None)
        print("[RustLedger] running " + shlex.join(command), file=sys.stderr, flush=True)
        return subprocess.call(command, env=env)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"[RustLedger] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
