#!/usr/bin/env python3
"""Prepare cached RustLedger artifacts, then run a Swift or Xcode command.

Example: Scripts/with-rustledger.py -- swift test --traits RustLedger
Cross-compilation requires --target, e.g. aarch64-apple-ios-sim.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys

from rustledger_build import ROOT, prepare


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
