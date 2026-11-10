import Foundation
import PackagePlugin

/// Adds prepared Swift bindings to the build without writing into package sources.
@main
struct RustLedgerBindingsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) -> [Command] {
        if let path = ProcessInfo.processInfo.environment["SWIFTBEANCOUNT_RUST_BINDINGS"] {
            return copyCommand(path: path, context: context)
        }
        // SwiftPM also plans plugins on unused targets in SwiftParser builds.
        guard let swiftTarget = target as? SwiftSourceModuleTarget,
              swiftTarget.compilationConditions.contains("RustLedger") else {
            return []
        }
        return preparedCommands(context: context)
    }

    private func preparedCommands(context: PluginContext) -> [Command] {
        let root = context.package.directoryURL
        let manifest = root.appendingPathComponent("Artifacts/RustLedger/current/manifest.json")
        guard FileManager.default.fileExists(atPath: manifest.path) else {
            Diagnostics.error("Prepare RustLedger with `python3 Scripts/prepare-rustledger-xcode.py`, then reopen the Xcode project. "
                              + "For source-based command-line builds, use Scripts/with-rustledger.py -- <swift or xcodebuild command>.")
            return []
        }
        return [
            .prebuildCommand(
                displayName: "Validate prepared RustLedger and copy Swift bindings",
                executable: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: [
                    root.appendingPathComponent("Scripts/rustledger_xcode.py").path,
                    "--root", root.path, "--output", context.pluginWorkDirectoryURL.appendingPathComponent("bindings").path
                ],
                outputFilesDirectory: context.pluginWorkDirectoryURL.appendingPathComponent("bindings")
            )
        ]
    }

    private func copyCommand(path: String, context: PluginContext) -> [Command] {
        let input = URL(fileURLWithPath: path)
        let output = context.pluginWorkDirectoryURL.appendingPathComponent("swiftbeancount_rust_ledger.swift")
        return [
            .buildCommand(
                displayName: "Copy prepared RustLedger bindings",
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "cmp -s \"$1\" \"$2\" || cp \"$1\" \"$2\"", "copy-bindings", input.path, output.path],
                inputFiles: [input],
                outputFiles: [output]
            )
        ]
    }
}
