#!/usr/bin/env python3
"""Validate persistent Xcode artifacts without requiring Cargo or pkg-config."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys


ARTIFACTS = Path("Artifacts/RustLedger")
PREPARE = "python3 Scripts/prepare-rustledger-xcode.py"


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def source_inputs(root: Path) -> dict[str, str]:
    """Include added/deleted Rust files, not just files known at preparation time."""
    paths = [root / "Scripts" / name for name in (
        "rustledger_build.py", "rustledger_xcode.py", "prepare-rustledger-xcode.py",
    )]
    for parent, children, files in os.walk(root / "Rust/SwiftBeanCountRustLedger"):
        children[:] = sorted(name for name in children if name not in ("target", ".git", ".build"))
        paths.extend(Path(parent) / name for name in sorted(files))
    return {str(path.relative_to(root)): digest(path) for path in sorted(paths)}


def validate(root: Path, directory: Path | None = None) -> dict:
    directory = directory or root / ARTIFACTS / "current"
    try:
        manifest = json.loads((directory / "manifest.json").read_text())
        if manifest["schema"] != 1 or manifest["inputs"] != source_inputs(root):
            raise ValueError("Rust sources or build scripts have changed")
        required = {"bindings.swift", "RustLedger.xcframework/Info.plist"}
        if not required.issubset(manifest["outputs"]):
            raise ValueError("Prepared artifact inventory is incomplete")
        for name, checksum in manifest["outputs"].items():
            if digest(directory / name) != checksum:
                raise ValueError(f"Prepared artifact changed: {name}")
        return manifest
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError(f"RustLedger artifacts are missing, stale, or damaged ({error}). Run `{PREPARE}` from the repository root, then reopen the Xcode project.") from error


def copy_bindings(root: Path, output: Path) -> None:
    # Resolve the publication once so validation and copying use the same build.
    directory = (root / ARTIFACTS / "current").resolve()
    validate(root, directory)
    source = directory / "bindings.swift"
    output.mkdir(parents=True, exist_ok=True)
    destination = output / "swiftbeancount_rust_ledger.swift"
    if not destination.exists() or digest(destination) != digest(source):
        temporary = destination.with_suffix(".tmp")
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path, help="Plugin directory for generated Swift bindings")
    args = parser.parse_args()
    try:
        if args.output:
            copy_bindings(args.root, args.output)
        else:
            validate(args.root)
        return 0
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
