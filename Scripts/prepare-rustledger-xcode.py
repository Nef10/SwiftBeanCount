#!/usr/bin/env python3
"""Compile Rust locally once, then build/run from an ordinarily opened Xcode.

Default: macOS, iOS device, and iOS Simulator for this Mac's architecture.
Use --platform macos for macOS only, or --universal for Intel + Apple silicon.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import uuid

from rustledger_build import ROOT, LIBRARY, capture, locked, prepare
from rustledger_xcode import ARTIFACTS, digest, source_inputs, validate


def destinations(selected: str, universal: bool) -> dict[str, list[str]]:
    architecture = {"arm64": "aarch64", "x86_64": "x86_64"}.get(platform.machine())
    if architecture is None:
        raise ValueError(f"Unsupported Mac architecture: {platform.machine()}")
    architectures = ["aarch64", "x86_64"] if universal else [architecture]
    groups = {}
    if selected in ("all", "macos"):
        groups["macos"] = [f"{arch}-apple-darwin" for arch in architectures]
    if selected in ("all", "ios"):
        groups["ios"] = ["aarch64-apple-ios"]
        groups["simulator"] = ["aarch64-apple-ios-sim" if arch == "aarch64" else "x86_64-apple-ios" for arch in architectures]
    return groups


def check_targets(groups: dict[str, list[str]]) -> None:
    missing = []
    for target in (target for group in groups.values() for target in group):
        directory = Path(capture(["rustc", "--print", "target-libdir", "--target", target]))
        if not list(directory.glob("libstd-*.rlib")):
            missing.append(target)
    if missing:
        raise ValueError("Install the pinned toolchain's destination libraries first: "
                         "rustup target add --toolchain 1.99.1 " + " ".join(missing)
                         + " (or use --platform macos for a Mac-only build)")


def assemble(stage: Path, groups: dict[str, list[str]], entries: dict[str, Path]) -> None:
    reference = next(iter(entries.values()))
    for entry in entries.values():
        for name in ("bindings.swift", f"{LIBRARY}_generated.h"):
            if digest(entry / name) != digest(reference / name):
                raise ValueError(f"UniFFI interface differs across destinations: {name}")
    shutil.copy2(reference / "bindings.swift", stage / "bindings.swift")
    headers = stage / "headers"
    headers.mkdir()
    header = f"{LIBRARY}FFI.h"
    shutil.copy2(reference / f"{LIBRARY}_generated.h", headers / header)
    (headers / "module.modulemap").write_text(
        f'module {LIBRARY}FFI {{\n    header "{header}"\n    export *\n}}\n')
    command = ["xcrun", "xcodebuild", "-create-xcframework"]
    for name, targets in groups.items():
        directory = stage / name
        directory.mkdir()
        archive = directory / f"lib{LIBRARY}.a"
        libraries = [str(entries[target] / archive.name) for target in targets]
        if len(libraries) == 1:
            shutil.copy2(libraries[0], archive)
        else:
            subprocess.run(["xcrun", "lipo", "-create", *libraries, "-output", str(archive)], check=True)
        command.extend(["-library", str(archive), "-headers", str(headers)])
    subprocess.run([*command, "-output", str(stage / "RustLedger.xcframework")], check=True)
    shutil.rmtree(headers)
    for name in groups:
        shutil.rmtree(stage / name)


def publish(args: argparse.Namespace) -> Path:
    groups = destinations(args.platform, args.universal)
    check_targets(groups)
    inputs = source_inputs(ROOT)
    entries = {}
    keys = {}
    for targets in groups.values():
        for target in targets:
            entry, _ = prepare(argparse.Namespace(target=target, profile=args.profile,
                                                 deployment_target=None, cache_dir=args.cache_dir))
            entries[target] = entry
            keys[target] = json.loads((entry / "manifest.json").read_text())["key"]
    if inputs != source_inputs(ROOT):
        raise ValueError("Rust inputs changed during preparation; rerun the command")
    identity = {"schema": 1, "inputs": inputs, "builds": keys}
    key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
    output = ROOT / ARTIFACTS
    builds = output / "builds"
    builds.mkdir(parents=True, exist_ok=True)
    current = output / "current"
    try:
        if validate(ROOT)["builds"] == keys:
            print("[RustLedger] XCFramework cache hit", file=sys.stderr)
            return current
    except ValueError:
        pass
    destination = builds / key
    try:
        validate(ROOT, destination)
        print("[RustLedger] XCFramework cache hit", file=sys.stderr)
    except ValueError:
        # Never remove a generation that an open Xcode may still be reading.
        if destination.exists():
            destination = builds / f"{key}-{uuid.uuid4().hex}"
        with tempfile.TemporaryDirectory(prefix=".preparing-", dir=builds) as temporary:
            stage = Path(temporary)
            assemble(stage, groups, entries)
            outputs = {str(path.relative_to(stage)): digest(path) for path in sorted(stage.rglob("*")) if path.is_file()}
            (stage / "manifest.json").write_text(json.dumps({**identity, "outputs": outputs}, indent=2) + "\n")
            if inputs != source_inputs(ROOT):
                raise ValueError("Rust inputs changed during packaging; rerun the command")
            os.replace(stage, destination)
    if not current.is_symlink() or current.resolve() != destination:
        link = output / f".current-{uuid.uuid4().hex}"
        try:
            link.symlink_to(Path("builds") / key, target_is_directory=True)
            os.replace(link, current)
        finally:
            link.unlink(missing_ok=True)
        # Notify an already-open Xcode that the package's binary target changed.
        (ROOT / "Package.swift").touch()
    return current


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("all", "macos", "ios"), default="all")
    parser.add_argument("--universal", action="store_true", help="Include both Intel and Apple silicon Mac/simulator slices")
    parser.add_argument("--profile", choices=("dev", "release"), default="release")
    parser.add_argument("--cache-dir", type=Path, default=ROOT / ".build/rustledger")
    args = parser.parse_args()
    try:
        if sys.platform != "darwin":
            raise ValueError("XCFramework preparation requires macOS and Xcode; use with-rustledger.py on Linux")
        with locked(ROOT / ARTIFACTS / ".prepare.lock"):
            directory = publish(args)
        print(f"RustLedger is ready: {directory}\nOpen SwiftBeanCountApp.xcodeproj normally, enable RustLedger, and build/run.\n"
              "If Xcode was already open, close and reopen the project to reload the package.")
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"[RustLedger] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
