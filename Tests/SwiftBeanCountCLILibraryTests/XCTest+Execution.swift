import Foundation
import XCTest

extension XCTest {

    var executableURL: URL {
        var url = Bundle(for: type(of: self)).bundleURL
        if url.lastPathComponent.hasSuffix("xctest") {
            url = url.deletingLastPathComponent()
        }
        return url.appendingPathComponent("swiftbeancount")
    }

    func outputFromExecutionWith(arguments: [String]) -> (Int32, String) {
        let output = Pipe()
        let process = Process()
        if #available(macOS 10.13, *) {
            process.executableURL = executableURL
        } else {
            process.launchPath = executableURL.path
        }
        process.arguments = arguments
        process.standardOutput = output

        if #available(macOS 10.13, *) {
            do {
                try process.run()
            } catch {
                XCTFail(error.localizedDescription)
            }
        } else {
            process.launch()
        }
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)

        return (process.terminationStatus, result)
    }

}
