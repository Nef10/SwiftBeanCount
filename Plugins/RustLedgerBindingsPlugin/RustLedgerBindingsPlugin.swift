import Foundation
import PackagePlugin

/// Adds prepared Swift bindings to the build without writing into package sources.
@main
struct RustLedgerBindingsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) -> [Command] {
        guard let path = ProcessInfo.processInfo.environment["SWIFTBEANCOUNT_RUST_BINDINGS"] else {
            // SwiftPM also plans plugins on unused targets in SwiftParser builds.
            if let swiftTarget = target as? SwiftSourceModuleTarget,
               swiftTarget.compilationConditions.contains("RustLedger") {
                Diagnostics.error("Build RustParser with Scripts/with-rustledger.py -- <swift or xcodebuild command>")
            }
            return []
        }
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
